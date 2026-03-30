import admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { PROJECT_REGION, MARKETPLACE_MAX_MEDIA_COUNT } from "../../../config/env";
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

async function readOwnerSignals(ownerId: string, normalizedTitle: string): Promise<{
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

export const submitListingDraft = onCall({ region: PROJECT_REGION }, async (request) => {
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
    const refsData = await ensureCategoryAndCityAreActive(validated.categoryId, validated.cityId);
    const ownerSignals = await readOwnerSignals(ownerId, validated.title.toLowerCase());

    const listingId = draftId;
    const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 90 * 24 * 60 * 60 * 1000));
    const cityData = refsData.city as Record<string, unknown>;

    await listingRef.set({
      id: listingId,
      ownerId,
      title: validated.title,
      description: validated.description,
      price: validated.price,
      categoryId: validated.categoryId,
      cityId: validated.cityId,
      media: validated.media,
      thumbnailUrl: validated.thumbnailUrl,
      status: "pending",
      moderationStatus: "pending",
      visibility: "private",
      mediaProcessingStatus: validated.media.length > 0 ? "processing" : "completed",
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

    const normalizedMedia = await normalizeListingMediaForSubmission({
      ownerId,
      media: validated.media,
    });
    const thumbnailUrl = normalizedMedia[0]?.thumbnailUrl || normalizedMedia[0]?.downloadUrl || "";

    if (normalizedMedia.length > 0) {
      await listingRef.set({
        media: normalizedMedia,
        thumbnailUrl,
        mediaProcessingStatus: "completed",
        updatedAt: now,
      }, { merge: true });
    }

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

    const publication = await persistModerationResult({
      listingId,
      ownerId,
      evaluation,
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
    } else {
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

export const incrementListingView = onCall({ region: PROJECT_REGION }, async (request) => {
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