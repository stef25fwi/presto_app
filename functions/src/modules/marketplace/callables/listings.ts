import admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION, MARKETPLACE_MAX_MEDIA_COUNT } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { createInAppNotification } from "../../notifications/push";
import { trackProductEventBackend } from "../services/analytics";
import { processOfferPhotoStoragePath } from "./media";
import {
  evaluateListingRisk,
  loadModerationConfig,
  persistModerationResult,
} from "../services/moderation";
import { verifyRecaptchaAssessment } from "../services/recaptcha";
import { toHttpsError } from "../services/errors";
import { validateListingDraftPayload } from "../validators/listings";
import type { ListingMedia } from "../models/firestore";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

function normalizeDisplayName(...values: unknown[]): string {
  for (const value of values) {
    const normalized = normalizeString(value);
    if (normalized) {
      return normalized;
    }
  }
  return "Annonceur iliprestō";
}

function readListingOwnerId(data: Record<string, unknown>): string {
  for (const field of ["ownerId", "userId", "uid"] as const) {
    const value = normalizeString(data[field]);
    if (value) {
      return value;
    }
  }
  return "";
}

function collectListingMediaStoragePaths(data: Record<string, unknown>): string[] {
  const media = Array.isArray(data.media) ? data.media as ListingMedia[] : [];
  return Array.from(new Set(
    media
      .map((entry) => normalizeString(entry.storagePath))
      .filter((storagePath) => storagePath.length > 0),
  ));
}

function collectListingImageUrls(media: ListingMedia[]): string[] {
  return Array.from(new Set(
    media
      .map((entry) => normalizeString(entry.downloadUrl || entry.thumbnailUrl))
      .filter((url) => url.length > 0),
  ));
}

function departmentFromPostalCode(postalCode: string): string {
  const cp = postalCode.trim();
  if (cp.length < 2) return "";
  if (cp.startsWith("97") || cp.startsWith("98")) {
    return cp.length >= 3 ? cp.slice(0, 3) : cp;
  }
  return cp.slice(0, 2);
}

function buildCategoryKeywords(label: string, categoryId: string): string[] {
  const tokens = `${label} ${categoryId}`
    .toLowerCase()
    .split(/[^a-z0-9]+/i)
    .map((value) => value.trim())
    .filter((value) => value.length >= 2);

  return Array.from(new Set(tokens)).slice(0, 20);
}

async function normalizeListingMediaForSubmission({
  ownerId,
  media,
}: {
  ownerId: string;
  media: ListingMedia[];
}): Promise<ListingMedia[]> {
  return Promise.all(media.map(async (entry) => {
    const storagePath = normalizeString(entry.storagePath);
    const mimeType = normalizeString(entry.mimeType).toLowerCase();

    if (!storagePath) {
      throw new HttpsError("invalid-argument", "Media storagePath is required");
    }

    if (storagePath.toLowerCase().endsWith(".webp") && mimeType === "image/webp") {
      return entry;
    }

    const processed = await processOfferPhotoStoragePath({
      uid: ownerId,
      storagePath,
    });

    return {
      storagePath: processed.storagePath,
      downloadUrl: processed.downloadUrl,
      thumbnailUrl: processed.thumbnailUrl,
      mimeType: processed.mimeType,
      width: processed.width,
      height: processed.height,
      sizeBytes: processed.sizeBytes,
      safeSearchStatus: "pending",
    };
  }));
}

async function loadDraftSnapshot(draftId: string) {
  const primaryRef = db.collection(COLLECTIONS.listingDraftsV2).doc(draftId);
  const primarySnap = await primaryRef.get();
  if (primarySnap.exists) {
    return primarySnap;
  }

  const legacyRef = db.collection(COLLECTIONS.listingDrafts).doc(draftId);
  const legacySnap = await legacyRef.get();
  if (legacySnap.exists) {
    return legacySnap;
  }

  throw new HttpsError("not-found", "Draft not found");
}

async function ensureCategoryAndCityAreActive(categoryId: string, cityId: string): Promise<Record<string, unknown>> {
  const [categorySnap, citySnap] = await Promise.all([
    db.collection(COLLECTIONS.categories).doc(categoryId).get(),
    db.collection(COLLECTIONS.cities).doc(cityId).get(),
  ]);

  if (!categorySnap.exists || categorySnap.data()?.isActive === false) {
    throw new HttpsError("failed-precondition", "Category is invalid or inactive");
  }
  if (!citySnap.exists || citySnap.data()?.isActive === false) {
    throw new HttpsError("failed-precondition", "City is invalid or inactive");
  }

  return {
    category: categorySnap.data() ?? {},
    city: citySnap.data() ?? {},
  };
}

async function ensureCategoryAndCityAreResolvable(
  validated: ReturnType<typeof validateListingDraftPayload>,
): Promise<Record<string, unknown>> {
  const [categorySnap, citySnap] = await Promise.all([
    db.collection(COLLECTIONS.categories).doc(validated.categoryId).get(),
    db.collection(COLLECTIONS.cities).doc(validated.cityId).get(),
  ]);

  if (categorySnap.exists && categorySnap.data()?.isActive === false) {
    throw new HttpsError("failed-precondition", "Category is invalid or inactive");
  }

  let categoryData = (categorySnap.data() ?? {}) as Record<string, unknown>;
  if (!categorySnap.exists) {
    const fallbackCategoryLabel = normalizeString(validated.category);
    if (!fallbackCategoryLabel) {
      throw new HttpsError("failed-precondition", "Category is invalid or inactive");
    }

    categoryData = {
      id: validated.categoryId,
      slug: validated.categoryId,
      label: fallbackCategoryLabel,
      isActive: true,
      searchableKeywords: buildCategoryKeywords(
        fallbackCategoryLabel,
        validated.categoryId,
      ),
    };

    await db.collection(COLLECTIONS.categories).doc(validated.categoryId).set(categoryData, { merge: true });
  }

  if (citySnap.exists && citySnap.data()?.isActive !== false) {
    return {
      category: categoryData,
      city: citySnap.data() ?? {},
    };
  }

  const fallbackCityLabel = normalizeString(validated.city || validated.location);
  const fallbackPostalCode = normalizeString(validated.postalCode || validated.cp);
  if (!fallbackCityLabel || !fallbackPostalCode) {
    throw new HttpsError("failed-precondition", "City is invalid or inactive");
  }

  const slug = validated.cityId.includes("_")
    ? validated.cityId.slice(validated.cityId.indexOf("_") + 1)
    : validated.cityId;
  const departmentCode = normalizeString(validated.dept) || departmentFromPostalCode(fallbackPostalCode);
  const fallbackCityData = {
    id: validated.cityId,
    slug,
    label: fallbackCityLabel,
    postalCodes: [fallbackPostalCode],
    primaryPostalCode: fallbackPostalCode,
    departmentCode: departmentCode || null,
    regionCode: normalizeString(validated.region) || null,
    isActive: true,
  };

  await db.collection(COLLECTIONS.cities).doc(validated.cityId).set(fallbackCityData, { merge: true });

  return {
    category: categoryData,
    city: fallbackCityData,
  };
}

async function readOwnerSignals(ownerId: string, normalizedTitle: string, excludeListingId?: string): Promise<{
  moderationStrikeCount: number;
  spamScore: number;
  lastRecaptchaScore?: number;
  recentListingCount: number;
  hasSimilarActiveListing: boolean;
}> {
  const [userSnap, listingSnap] = await Promise.all([
    db.collection(COLLECTIONS.users).doc(ownerId).get(),
    db.collection(COLLECTIONS.listings).where("ownerId", "==", ownerId).limit(20).get(),
  ]);

  const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
  const now = Date.now();
  const recentListingCount = listingSnap.docs.filter((doc) => {
    const createdAt = doc.data().createdAt;
    if (createdAt instanceof admin.firestore.Timestamp) {
      return now - createdAt.toMillis() <= 24 * 60 * 60 * 1000;
    }
    return false;
  }).length;

  const hasSimilarActiveListing = listingSnap.docs.some((doc) => {
    if (excludeListingId && doc.id === excludeListingId) return false;
    const data = doc.data();
    const status = normalizeString(data.status).toLowerCase();
    const sameTitle = normalizeString(data.title).toLowerCase() === normalizedTitle;
    return sameTitle && (status === "active" || status === "pending");
  });

  return {
    moderationStrikeCount: Number(userData.moderationStrikeCount || 0),
    spamScore: Number(userData.spamScore || 0),
    lastRecaptchaScore: typeof userData.lastRecaptchaScore === "number"
      ? Number(userData.lastRecaptchaScore)
      : undefined,
    recentListingCount,
    hasSimilarActiveListing,
  };
}

async function loadOwnerPublicIdentity(ownerId: string): Promise<{
  displayName: string;
  avatarUrl: string;
  verified: boolean;
}> {
  const userSnap = await db.collection(COLLECTIONS.users).doc(ownerId).get();
  const userData = (userSnap.data() ?? {}) as Record<string, unknown>;

  // Tente d'abord les champs Firestore
  const displayName = normalizeDisplayName(
    userData.pseudo, userData.displayName, userData.userName,
    userData.user_name, userData.name,
  );
  const avatarUrl = normalizeString(userData.avatarUrl || userData.photoURL);
  const verified = userData.isProfileVerified === true ||
    userData.isVerified === true ||
    userData.verified === true;

  // Fallback Auth uniquement si displayName manquant
  if (displayName === "Annonceur iliprestō") {
    const authRecord = await admin.auth().getUser(ownerId).catch(() => null);
    const emailPrefix = normalizeString(authRecord?.email).split("@").shift() ?? "";
    return {
      displayName: normalizeDisplayName(authRecord?.displayName, emailPrefix),
      avatarUrl: avatarUrl || normalizeString(authRecord?.photoURL),
      verified,
    };
  }

  return { displayName, avatarUrl, verified };
}

export const submitListingDraft = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const ownerId = requireAuthUid(request);
  const draftId = normalizeString(request.data?.draftId);
  const recaptchaToken = normalizeString(request.data?.recaptchaToken);

  if (!draftId) {
    throw new HttpsError("invalid-argument", "draftId is required");
  }

  const rateAllowed = await canProceedRateLimited("listing_submit", ownerId, 5, 60 * 60 * 1000);
  if (!rateAllowed) {
    throw new HttpsError("resource-exhausted", "Too many listing submissions, please retry later");
  }

  const recaptcha = await verifyRecaptchaAssessment({
    token: recaptchaToken,
    expectedAction: "listing_submit",
    userId: ownerId,
  });
  if (!recaptcha.allowed) {
    throw new HttpsError("permission-denied", "reCAPTCHA assessment rejected the listing submission");
  }

  try {
    const config = await loadModerationConfig();
    const draftSnap = await loadDraftSnapshot(draftId);
    const draftData = (draftSnap.data() ?? {}) as Record<string, unknown>;
    if (normalizeString(draftData.ownerId) !== ownerId) {
      throw new HttpsError("permission-denied", "You do not own this draft");
    }

    const validated = validateListingDraftPayload(draftData, config.maxMediaCount || MARKETPLACE_MAX_MEDIA_COUNT);
    const refsData = await ensureCategoryAndCityAreResolvable(validated);
    const listingId = draftId;
    const ownerSignals = await readOwnerSignals(ownerId, validated.title.toLowerCase(), listingId);
    const ownerIdentity = await loadOwnerPublicIdentity(ownerId);

    const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 90 * 24 * 60 * 60 * 1000));
    const cityData = refsData.city as Record<string, unknown>;

    // 1. Traiter les médias AVANT tout write Firestore (évite la race condition)
    const normalizedMedia = validated.media.length > 0
      ? await normalizeListingMediaForSubmission({ ownerId, media: validated.media })
      : validated.media;
    const thumbnailUrl = normalizedMedia[0]?.thumbnailUrl || normalizedMedia[0]?.downloadUrl || "";
    const imageUrls = collectListingImageUrls(normalizedMedia);

    // 2. UN SEUL write avec toutes les données complètes
    await listingRef.set({
      id: listingId,
      ownerId,
      title: validated.title,
      description: validated.description,
      price: validated.price,
      budgetValue: validated.budgetValue ?? validated.price,
      categoryId: validated.categoryId,
      category: validated.category || null,
      cityId: validated.cityId,
      city: validated.city || validated.location || null,
      location: validated.location || validated.city || null,
      postalCode: validated.postalCode || validated.cp || null,
      cp: validated.cp || validated.postalCode || null,
      dept: validated.dept || normalizeString(cityData.departmentCode) || null,
      region: validated.region || normalizeString(cityData.regionCode) || null,
      cityCategoryKey: validated.cityCategoryKey || null,
      media: normalizedMedia,
      imageUrls,
      thumbnailUrl,
      ownerName: ownerIdentity.displayName,
      displayName: ownerIdentity.displayName,
      userName: ownerIdentity.displayName,
      pseudo: ownerIdentity.displayName,
      avatarUrl: ownerIdentity.avatarUrl || null,
      verified: ownerIdentity.verified,
      advertiser: {
        id: ownerId,
        name: ownerIdentity.displayName,
        avatarUrl: ownerIdentity.avatarUrl || null,
        verified: ownerIdentity.verified,
      },
      phone: validated.phone || null,
      budgetType: validated.budgetType || null,
      missionDelay: validated.missionDelay || null,
      isUrgent: validated.isUrgent,
      subCategory: validated.subCategory || null,
      status: "pending",
      moderationStatus: "pending",
      visibility: "private",
      mediaProcessingStatus: "completed",
      reportCount: 0,
      favoriteCount: 0,
      viewCount: 0,
      contactCount: 0,
      isBoosted: false,
      boostExpiresAt: null,
      createdAt: now,
      updatedAt: now,
      publishedAt: null,
      expiresAt,
      searchKeywords: validated.searchKeywords,
      locationApprox: cityData.geo && typeof cityData.geo === "object"
        ? cityData.geo
        : null,
      sourceDraftId: draftId,
      riskScore: 0,
    }, { merge: true });

    const evaluation = await evaluateListingRisk({
      ownerId,
      title: validated.title,
      description: validated.description,
      media: normalizedMedia,
      ownerSignals: {
        ...ownerSignals,
        lastRecaptchaScore: recaptcha.score,
      },
    });
    // Photos are processed synchronously above, so no need for deferred
    // autoPublishAfter — publish immediately when approved.
    const autoPublishAfter = null;

    const publication = await persistModerationResult({
      listingId,
      ownerId,
      evaluation,
      autoApproveEnabled: config.autoApproveEnabled,
      autoPublishAfter,
    });

    await draftSnap.ref.set({
      status: "submitted",
      submittedAt: now,
      listingId,
      updatedAt: now,
    }, { merge: true });

    const routeName = `/listings/${encodeURIComponent(listingId)}`;
    if (publication.status === "active") {
      await createInAppNotification({
        notificationId: `listing_approved_${listingId}`,
        userId: ownerId,
        title: "Annonce publiee",
        message: validated.title,
        type: "listing_approved",
        routeName,
        offerId: listingId,
      });
      await trackProductEventBackend({
        eventName: "listing_published",
        userId: ownerId,
        listingId,
        params: {
          moderation_status: publication.moderationStatus,
          recaptcha_score: recaptcha.score,
        },
      });
    } else if (publication.status === "rejected") {
      await createInAppNotification({
        notificationId: `listing_rejected_${listingId}`,
        userId: ownerId,
        title: "Annonce rejetee",
        message: evaluation.moderationReason,
        type: "listing_rejected",
        routeName,
        offerId: listingId,
      });
      await trackProductEventBackend({
        eventName: "listing_rejected",
        userId: ownerId,
        listingId,
        params: {
          moderation_status: publication.moderationStatus,
          risk_score: evaluation.riskScore,
        },
      });
    } else if (publication.moderationStatus !== "approved") {
      await createInAppNotification({
        notificationId: `listing_manual_review_${listingId}`,
        userId: ownerId,
        title: "Annonce en revue",
        message: "Votre annonce est en attente de moderation.",
        type: "manual_review_required",
        routeName,
        offerId: listingId,
      });
    }

    await trackProductEventBackend({
      eventName: "listing_submitted",
      userId: ownerId,
      listingId,
      params: {
        moderation_status: publication.moderationStatus,
        risk_score: evaluation.riskScore,
        auto_flags_count: evaluation.autoFlags.length,
        recaptcha_score: recaptcha.score,
      },
    });

    logger.info("marketplace_listing_submitted", {
      listingId,
      ownerId,
      moderationStatus: publication.moderationStatus,
      status: publication.status,
      riskScore: evaluation.riskScore,
    });

    return {
      ok: true,
      listingId,
      status: publication.status,
      moderationStatus: publication.moderationStatus,
      visibility: publication.visibility,
      riskScore: evaluation.riskScore,
      media: normalizedMedia,
      thumbnailUrl,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to submit listing draft");
  }
});

export const incrementListingView = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const listingId = normalizeString(request.data?.listingId);
  const viewerKey = normalizeString(request.data?.viewerKey);
  const viewerId = normalizeString(request.auth?.uid) || viewerKey;

  if (!listingId || !viewerId) {
    throw new HttpsError("invalid-argument", "listingId and viewer identity are required");
  }

  const allowed = await canProceedRateLimited(
    "listing_view",
    `${listingId}:${viewerId}`,
    1,
    24 * 60 * 60 * 1000,
  );
  if (!allowed) {
    return { ok: true, deduplicated: true };
  }

  const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
  const listingSnap = await listingRef.get();
  if (!listingSnap.exists) {
    throw new HttpsError("not-found", "Listing not found");
  }

  const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
  if (normalizeString(listingData.status) !== "active" || normalizeString(listingData.visibility) !== "public") {
    throw new HttpsError("failed-precondition", "Listing is not public");
  }

  await listingRef.set({
    viewCount: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await trackProductEventBackend({
    eventName: "listing_view",
    userId: normalizeString(request.auth?.uid) || undefined,
    listingId,
    params: {
      source: normalizeString(request.data?.source) || "unknown",
    },
  });

  return { ok: true, deduplicated: false };
});

/**
 * Valid structured reasons indicating "job done".
 */
const VALID_JOB_DONE_REASONS = ['found_on_ilipresto', 'found_provider_elsewhere'] as const;

/**
 * Checks if the deletion reason corresponds to a "job done" scenario
 * where the listing should be kept visible with an overlay instead of hard-deleted.
 * Accepts a structured enum value OR falls back to textual detection for backward compatibility.
 */
function isJobDoneReason(reason: string | undefined, jobDone?: boolean): boolean {
  if (jobDone === true) return true;
  if (!reason) return false;
  // Structured enum check
  if ((VALID_JOB_DONE_REASONS as readonly string[]).includes(reason)) return true;
  // Legacy textual detection (backward compat)
  const normalized = reason
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/['']/g, "'")
    .replace(/\s+/g, " ");
  const foundOnIliPresto =
    normalized.includes("trouve quelqu") && normalized.includes("ilipresto");
  const foundProvider =
    normalized.includes("deja trouve") && normalized.includes("prestataire");
  return foundOnIliPresto || foundProvider;
}

const JOB_DONE_OVERLAY_HOURS = 10;

export const deleteListing = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const ownerId = requireAuthUid(request);
  const listingId = normalizeString(request.data?.listingId);
  const reason = typeof request.data?.reason === "string"
    ? request.data.reason.trim().slice(0, 500)
    : undefined;

  if (!listingId) {
    throw new HttpsError("invalid-argument", "listingId is required");
  }

  try {
    const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
    const listingSnap = await listingRef.get();

    if (!listingSnap.exists) {
      throw new HttpsError("not-found", "Listing not found");
    }

    const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
    const listingOwnerId = readListingOwnerId(listingData);
    if (listingOwnerId !== ownerId) {
      throw new HttpsError("permission-denied", "You do not own this listing");
    }

    const previousStatus = normalizeString(listingData.status) || "unknown";
    const mediaStoragePaths = collectListingMediaStoragePaths(listingData);

    if (isJobDoneReason(reason, request.data?.jobDone === true)) {
      // Keep the listing public for 10h so browse queries can still fetch it
      // and render the job-done overlay before it disappears client-side.
      const visibleUntil = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + JOB_DONE_OVERLAY_HOURS * 60 * 60 * 1000),
      );
      await listingRef.update({
        status: "active",
        visibility: "public",
        isActive: true,
        isPublished: true,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        deletedReason: reason,
        archiveReason: reason,
        jobDoneOverlayVisible: true,
        jobDoneOverlayVisibleUntil: visibleUntil,
        removeFromBrowseAt: visibleUntil,
      });

      logger.info("marketplace_listing_marked_job_done", {
        listingId,
        ownerId,
        previousStatus,
        reason,
      });

      return { ok: true, listingId, jobDone: true };
    }

    const bucket = admin.storage().bucket();
    await Promise.all(mediaStoragePaths.map(async (storagePath) => {
      try {
        await bucket.file(storagePath).delete();
      } catch {
        // Best effort: media cleanup must not block listing deletion.
      }
    }));

    // Hard-delete the listing and related documents.
    const batch = db.batch();
    // Archive avant hard-delete (traçabilité modération, RGPD, analytics)
    const archiveRef = db.collection('deletedListings').doc(listingId);
    batch.set(archiveRef, {
      ...listingData,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedBy: ownerId,
      deletedReason: reason || 'user_request',
      originalListingId: listingId,
    });
    batch.delete(listingRef);
    batch.delete(db.collection(COLLECTIONS.listingModeration).doc(listingId));
    batch.delete(db.collection(COLLECTIONS.listingDraftsV2).doc(listingId));
    batch.delete(db.collection(COLLECTIONS.listingDrafts).doc(listingId));
    await batch.commit();

    logger.info("marketplace_listing_deleted", {
      listingId,
      ownerId,
      previousStatus,
      reason: reason || "none",
    });

    return {
      ok: true,
      listingId,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to delete listing");
  }
});