import admin from "../../../core/firebase_admin_compat";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION, MARKETPLACE_MAX_MEDIA_COUNT } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS, LEGACY_COLLECTIONS } from "../../../shared/constants";
import { createInAppNotification } from "../../notifications/push";
import { trackProductEventBackend } from "../services/analytics";
import { processOfferPhotoStoragePath } from "./media";
import {
  evaluateListingRisk,
  loadModerationConfig,
  persistModerationResult,
} from "../services/moderation";
import {
  sendListingModerationSystemMessage,
  sendTeamBroadcastMessage,
} from "../services/system_messages";
import { verifyRecaptchaAssessment } from "../services/recaptcha";
import { shouldRejectListingSubmissionForRecaptcha } from "../services/recaptcha";
import { toHttpsError } from "../services/errors";
import { extractRolesFromAuthToken } from "../services/roles";
import { validateListingDraftPayload, validateListingMedia } from "../validators/listings";
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

export function buildListingDraftDocumentPath(draftId: string): string {
  return `${COLLECTIONS.listingDrafts}/${draftId}`;
}

export function buildListingDocumentPath(listingId: string): string {
  return `${COLLECTIONS.listings}/${listingId}`;
}

export function assertDraftOwnership(
  ownerId: string,
  draftData: Record<string, unknown>,
): void {
  if (normalizeString(draftData.ownerId) !== ownerId) {
    throw new HttpsError("permission-denied", "You do not own this draft");
  }
}

export function assertCategoryAndCityConfigured({
  categoryExists,
  categoryActive,
  cityExists,
  cityActive,
}: {
  categoryExists: boolean;
  categoryActive: boolean;
  cityExists: boolean;
  cityActive: boolean;
}): void {
  if (!categoryExists || !categoryActive || !cityExists || !cityActive) {
    throw new HttpsError("failed-precondition", "Category or city is not configured");
  }
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

function sanitizeDraftPayload(rawDraft: Record<string, unknown>, ownerId: string): Record<string, unknown> {
  const allowedFields = [
    "title",
    "description",
    "price",
    "categoryId",
    "cityId",
    "media",
    "status",
    "phone",
    "hidePhone",
    "budgetType",
    "missionDelay",
    "isUrgent",
    "subCategory",
    "category",
    "city",
    "location",
    "postalCode",
    "cp",
    "dept",
    "region",
    "cityCategoryKey",
    "budgetValue",
  ];

  const sanitized: Record<string, unknown> = {
    ownerId,
    media: [],
    status: "draft",
  };

  for (const field of allowedFields) {
    if (Object.prototype.hasOwnProperty.call(rawDraft, field)) {
      sanitized[field] = rawDraft[field];
    }
  }

  sanitized.ownerId = ownerId;
  sanitized.status = normalizeString(sanitized.status) || "draft";
  sanitized.media = Array.isArray(sanitized.media) ? sanitized.media : [];
  return sanitized;
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

function extractDialingCode(rawPhone: string): string {
  const compact = normalizeString(rawPhone).replace(/[\s().-]+/g, "");
  if (!compact) return "";

  const supportedDialingCodes = [
    "+590", // Guadeloupe, Saint-Martin, Saint-Barthélemy
    "+596", // Martinique
    "+594", // Guyane
    "+262", // La Réunion et Mayotte
    "+508", // Saint-Pierre-et-Miquelon
    "+681", // Wallis-et-Futuna
    "+689", // Polynésie française
    "+687", // Nouvelle-Calédonie
    "+33", // France métropolitaine
  ];

  for (const dialingCode of supportedDialingCodes) {
    if (compact.startsWith(dialingCode)) {
      return dialingCode;
    }
  }

  const fallback = compact.match(/^(\+\d{1,3})/);
  if (fallback?.[1]) return fallback[1];

  const localPrefixToDialingCode: Record<string, string> = {
    "0590": "+590",
    "0596": "+596",
    "0594": "+594",
    "0262": "+262",
    "0269": "+262",
    "0508": "+508",
    "0681": "+681",
    "0689": "+689",
    "0687": "+687",
  };

  for (const [prefix, dialingCode] of Object.entries(localPrefixToDialingCode)) {
    if (compact.startsWith(prefix)) {
      return dialingCode;
    }
  }

  if (compact.length === 10 && compact.startsWith("0")) return "+33";
  if (compact.length === 9 && (compact.startsWith("6") || compact.startsWith("7"))) {
    return "+33";
  }

  return "";
}

export function buildAutoPublishAfterForSubmission({
  mediaCount,
  nowMs = Date.now(),
}: {
  mediaCount: number;
  nowMs?: number;
}): admin.firestore.Timestamp | null {
  if (mediaCount <= 0) {
    return null;
  }

  return admin.firestore.Timestamp.fromMillis(nowMs + 30 * 1000);
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
  draftId,
  listingId,
  media,
}: {
  ownerId: string;
  draftId: string;
  listingId: string;
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
      draftId,
      listingId,
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
  const primaryRef = db.collection(COLLECTIONS.listingDrafts).doc(draftId);
  const primarySnap = await primaryRef.get();
  if (primarySnap.exists) {
    return primarySnap;
  }

  const legacyRef = db.collection(LEGACY_COLLECTIONS.listingDrafts).doc(draftId);
  const legacySnap = await legacyRef.get();
  if (legacySnap.exists) {
    return legacySnap;
  }

  throw new HttpsError("not-found", "Draft not found");
}

async function ensureCategoryAndCityAreResolvable(
  validated: ReturnType<typeof validateListingDraftPayload>,
): Promise<Record<string, unknown>> {
  const [categorySnap, citySnap] = await Promise.all([
    db.collection(COLLECTIONS.categories).doc(validated.categoryId).get(),
    db.collection(COLLECTIONS.cities).doc(validated.cityId).get(),
  ]);

  // Catégorie : doit exister dans la taxonomie — on ne crée pas de documents
  // fantômes depuis des labels libres envoyés par le client.
  if (!categorySnap.exists || categorySnap.data()?.isActive === false) {
    throw new HttpsError("failed-precondition", "Category is invalid or inactive");
  }

  const categoryData = categorySnap.data() as Record<string, unknown>;

  // Ville inactive (désactivée par un admin) : on rejette plutôt que de
  // réécrire isActive:true via merge, ce qui annulerait la désactivation.
  if (citySnap.exists && citySnap.data()?.isActive === false) {
    throw new HttpsError("failed-precondition", "City is invalid or inactive");
  }

  if (citySnap.exists) {
    return {
      category: categoryData,
      city: citySnap.data() ?? {},
    };
  }

  // Ville inconnue de Firestore (non seedée) : on la crée à la volée depuis
  // les données vérifiées du brouillon (CP + nom issus de geo.api.gouv.fr).
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

  await db.collection(COLLECTIONS.cities).doc(validated.cityId).set(fallbackCityData);

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

export const createListingDraft = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const ownerId = requireAuthUid(request);
  const rawDraft = (request.data?.draft ?? {}) as Record<string, unknown>;
  const draft = sanitizeDraftPayload(rawDraft, ownerId);

  try {
    validateListingDraftPayload(draft, MARKETPLACE_MAX_MEDIA_COUNT);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const draftRef = db.collection(COLLECTIONS.listingDrafts).doc();
    await draftRef.set({
      ...draft,
      createdAt: now,
      updatedAt: now,
    });

    await trackProductEventBackend({
      eventName: "listing_create_completed",
      userId: ownerId,
      listingId: draftRef.id,
      params: {
        category_id: normalizeString(draft.categoryId),
        city_id: normalizeString(draft.cityId),
        media_count: Array.isArray(draft.media) ? draft.media.length : 0,
      },
    });

    return { ok: true, draftId: draftRef.id };
  } catch (error) {
    throw toHttpsError(error, "Unable to create listing draft");
  }
});

export const updateListingDraftMedia = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const ownerId = requireAuthUid(request);
  const draftId = normalizeString(request.data?.draftId);

  if (!draftId) {
    throw new HttpsError("invalid-argument", "draftId is required");
  }

  try {
    const media = validateListingMedia(request.data?.media, MARKETPLACE_MAX_MEDIA_COUNT);
    const draftSnap = await loadDraftSnapshot(draftId);
    const draftData = (draftSnap.data() ?? {}) as Record<string, unknown>;
    assertDraftOwnership(ownerId, draftData);

    await draftSnap.ref.set({
      media,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, draftId, mediaCount: media.length };
  } catch (error) {
    throw toHttpsError(error, "Unable to update listing draft media");
  }
});

export const submitListingDraft = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const deploymentRevision = "2026-05-19-recaptcha-env-refresh";
  void deploymentRevision;

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
  if (shouldRejectListingSubmissionForRecaptcha(recaptcha)) {
    throw new HttpsError("permission-denied", "reCAPTCHA assessment rejected the listing submission");
  }
  if (!recaptcha.allowed) {
    logger.warn("marketplace_listing_submit_low_recaptcha_score", {
      ownerId,
      draftId,
      score: recaptcha.score,
      reasons: recaptcha.reasons,
      action: recaptcha.action,
    });
  }

  try {
    const config = await loadModerationConfig();
    const draftSnap = await loadDraftSnapshot(draftId);
    const draftData = (draftSnap.data() ?? {}) as Record<string, unknown>;
    assertDraftOwnership(ownerId, draftData);

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
      ? await normalizeListingMediaForSubmission({
        ownerId,
        draftId,
        listingId,
        media: validated.media,
      })
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
      hidePhone: validated.hidePhone,
      phone: admin.firestore.FieldValue.delete(),
      telephone: admin.firestore.FieldValue.delete(),
      contactPhone: admin.firestore.FieldValue.delete(),
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

    const privateContactRef = db.collection("listingPrivateContacts").doc(listingId);
    if (validated.phone) {
      await privateContactRef.set({
        listingId,
        ownerId,
        phone: validated.phone,
        hidePhone: validated.hidePhone,
        createdAt: now,
        updatedAt: now,
      }, { merge: true });
    } else {
      await privateContactRef.delete().catch(() => undefined);
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
    // Keep photo listings in pending briefly so users see the validation step
    // before the scheduler flips them to public/active.
    const autoPublishAfter = buildAutoPublishAfterForSubmission({
      mediaCount: normalizedMedia.length,
    });

    const publication = await persistModerationResult({
      listingId,
      listingTitle: validated.title,
      ownerId,
      media: normalizedMedia,
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
      await sendListingModerationSystemMessage({
        ownerId,
        listingId,
        listingTitle: validated.title,
        body: evaluation.autoFlags.includes("banned_term")
          ? "Bonjour, votre annonce contient un texte qui ne respecte pas nos règles de publication. Merci de modifier le titre ou la description avant de la soumettre à nouveau."
          : "Bonjour, votre annonce n’a pas pu être publiée car une image ajoutée ne respecte pas nos règles de modération. Merci de remplacer cette photo par une image claire, conforme et sans contenu sensible. Votre annonce pourra ensuite être soumise à nouveau.",
      });
      await createInAppNotification({
        notificationId: `listing_rejected_${listingId}`,
        userId: ownerId,
        title: "Annonce rejetee",
        message: evaluation.moderationUserMessage || evaluation.moderationReason,
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

export const getListingContactPhone = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const listingId = normalizeString(request.data?.listingId);
  if (!listingId) {
    throw new HttpsError("invalid-argument", "listingId is required");
  }

  const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
  const [listingSnap, privateContactSnap] = await Promise.all([
    listingRef.get(),
    db.collection("listingPrivateContacts").doc(listingId).get(),
  ]);

  if (!listingSnap.exists) {
    throw new HttpsError("not-found", "Listing not found");
  }

  const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
  const status = normalizeString(listingData.status).toLowerCase();
  const visibility = normalizeString(listingData.visibility).toLowerCase();
  const hidePhone = listingData.hidePhone === true;

  const uid = normalizeString(request.auth?.uid);
  const ownerId = readListingOwnerId(listingData);
  const isOwner = uid.length > 0 && uid === ownerId;
  const isPublic = status === "active" && visibility === "public";

  if (!isPublic && !isOwner) {
    throw new HttpsError("permission-denied", "Listing is not publicly visible");
  }

  const privateData = (privateContactSnap.data() ?? {}) as Record<string, unknown>;
  const phone = normalizeString(privateData.phone);
  const dialingCode = extractDialingCode(phone);

  if (!phone) {
    return {
      ok: true,
      hidePhone,
      dialingCode: "",
      phone: "",
    };
  }

  if (hidePhone) {
    return {
      ok: true,
      hidePhone: true,
      dialingCode,
      phone: "",
    };
  }

  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }

  return {
    ok: true,
    hidePhone: false,
    dialingCode,
    phone,
  };
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

function isFoundOnIliPrestoReason(reason: string | undefined): boolean {
  if (!reason) return false;
  const normalized = reason
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[']/g, "'")
    .replace(/\s+/g, " ");
  return normalized === "found_on_ilipresto" ||
    (normalized.includes("trouve quelqu") && normalized.includes("ilipresto"));
}

const JOB_DONE_OVERLAY_HOURS = 10;

export async function closeOrDeleteListingForOwner({
  actorId,
  listingId,
  reason,
  jobDone,
  allowAdminDelete = false,
}: {
  actorId: string;
  listingId: string;
  reason?: string;
  jobDone?: boolean;
  allowAdminDelete?: boolean;
}): Promise<Record<string, unknown>> {
    const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
    const listingSnap = await listingRef.get();

    if (!listingSnap.exists) {
      throw new HttpsError("not-found", "Listing not found");
    }

    const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
    const listingOwnerId = readListingOwnerId(listingData);
    const isOwnerDelete = listingOwnerId === actorId;
    const isAdminDelete = allowAdminDelete && !isOwnerDelete;
    if (!isOwnerDelete && !isAdminDelete) {
      throw new HttpsError("permission-denied", "You do not own this listing");
    }

    const previousStatus = normalizeString(listingData.status) || "unknown";
    const listingTitle =
      normalizeString(listingData.title) || "votre annonce";
    const mediaStoragePaths = collectListingMediaStoragePaths(listingData);

    if (isJobDoneReason(reason, jobDone === true)) {
      // Keep the listing public for 10h so browse queries can still fetch it
      // and render the job-done overlay before it disappears client-side.
      const visibleUntil = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + JOB_DONE_OVERLAY_HOURS * 60 * 60 * 1000),
      );
      const reviewRequested = isFoundOnIliPrestoReason(reason);
      await listingRef.update({
        status: "active",
        visibility: "public",
        isActive: true,
        isPublished: true,
        closedReason: reason,
        closedAt: admin.firestore.FieldValue.serverTimestamp(),
        selectedUserId: null,
        reviewRequested,
        reviewSubmitted: false,
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
        ownerId: listingOwnerId,
        actorId,
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
      deletedBy: actorId,
      deletedForOwnerId: listingOwnerId,
      deletedByAdmin: isAdminDelete,
      deletedReason: reason || 'user_request',
      originalListingId: listingId,
    });
    batch.delete(listingRef);
    batch.delete(db.collection(COLLECTIONS.listingModeration).doc(listingId));
    batch.delete(db.collection(COLLECTIONS.listingDrafts).doc(listingId));
    batch.delete(db.collection(LEGACY_COLLECTIONS.listingDrafts).doc(listingId));
    await batch.commit();

    logger.info("marketplace_listing_deleted", {
      listingId,
      ownerId: listingOwnerId,
      actorId,
      adminDelete: isAdminDelete,
      previousStatus,
      reason: reason || "none",
    });

    if (isAdminDelete && listingOwnerId) {
      await sendTeamBroadcastMessage({
        userId: listingOwnerId,
        messageId: `listing_deleted_${listingId}`,
        body:
          `Bonjour, votre annonce "${listingTitle}" a ete supprimee par l'equipe ilipresto.`,
        campaignTitle: "Annonce supprimée",
      });
    }

    return {
      ok: true,
      listingId,
      ownerId: listingOwnerId,
      adminDelete: isAdminDelete,
    };
}

export const deleteListing = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const actorId = requireAuthUid(request);
  const actorRoles = extractRolesFromAuthToken(
    request.auth?.token as Record<string, unknown> | undefined,
  );
  const allowAdminDelete =
    actorRoles.includes("admin") || actorRoles.includes("superadmin");
  const listingId = normalizeString(request.data?.listingId);
  const reason = typeof request.data?.reason === "string"
    ? request.data.reason.trim().slice(0, 500)
    : undefined;

  if (!listingId) {
    throw new HttpsError("invalid-argument", "listingId is required");
  }

  try {
    return await closeOrDeleteListingForOwner({
      actorId,
      listingId,
      reason,
      jobDone: request.data?.jobDone === true,
      allowAdminDelete,
    });
  } catch (error) {
    throw toHttpsError(error, "Unable to delete listing");
  }
});

export const closeOfferWithReason = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const actorId = requireAuthUid(request);
  const listingId = normalizeString(request.data?.offerId || request.data?.listingId);
  const reason = typeof request.data?.reason === "string"
    ? request.data.reason.trim().slice(0, 500)
    : undefined;

  if (!listingId) {
    throw new HttpsError("invalid-argument", "offerId is required");
  }
  if (!reason) {
    throw new HttpsError("invalid-argument", "reason is required");
  }

  try {
    return await closeOrDeleteListingForOwner({
      actorId,
      listingId,
      reason,
      jobDone: request.data?.jobDone === true,
    });
  } catch (error) {
    throw toHttpsError(error, "Unable to close listing");
  }
});