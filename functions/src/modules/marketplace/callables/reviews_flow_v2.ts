import admin from "../../../core/firebase_admin_compat";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { readConversationParticipants } from "../../messaging/participants";
import { createInAppNotification } from "../../notifications/push";
import { toHttpsError } from "../services/errors";

const REVIEWS_COLLECTION = "reviews";
const TRUST_SCORES_V2_COLLECTION = "user_trust_scores_v2";
const REVIEW_WINDOW_DAYS = 14;
const BAYESIAN_MIN_REVIEWS = 10;
const PLATFORM_DEFAULT_AVERAGE = 4.2;

type ReviewRole = "requester" | "provider";
type ReviewStatus =
  | "published"
  | "pending_peer_review"
  | "pending_moderation"
  | "rejected"
  | "disputed"
  | "hidden";

type PendingReviewTaskType = "reciprocal" | "rate_later" | "correction";

interface ModerationFlags {
  containsPersonalData: boolean;
  containsInsult: boolean;
  containsThreat: boolean;
  containsSuspiciousContent: boolean;
}

interface ReviewForScore {
  id: string;
  offerId: string;
  offerTitle: string;
  reviewerId: string;
  reviewedUserId: string;
  reviewerRole: ReviewRole;
  reviewedRole: ReviewRole;
  criteria: Record<string, number>;
  averageRating: number;
  reliableWeight: number;
  comment: string | null;
  replyText: string | null;
  createdAtMillis: number | null;
  publishedAtMillis: number | null;
}

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) throw new HttpsError("unauthenticated", "Authentication is required");
  return uid;
}

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

function normalizeSearchText(value: string): string {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function readTimestampMillis(value: unknown): number | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}

function readListingOwnerId(data: Record<string, unknown>): string {
  return normalizeString(data.ownerId) || normalizeString(data.userId) || normalizeString(data.uid);
}

function readDisplayName(data: Record<string, unknown>, fallback = "Utilisateur iliprestō"): string {
  for (const field of ["pseudo", "displayName", "display_name", "username", "name"] as const) {
    const value = normalizeString(data[field]);
    if (value) return value;
  }
  return fallback;
}

function readCity(data: Record<string, unknown>): string {
  for (const field of ["city", "ville", "commune", "locality", "cityLabel"] as const) {
    const value = normalizeString(data[field]);
    if (value) return value;
  }
  return "";
}

function readPhotoUrl(data: Record<string, unknown>): string | null {
  for (const field of ["photoUrl", "photoURL", "avatarUrl", "avatar", "profilePhotoUrl"] as const) {
    const value = normalizeString(data[field]);
    if (value) return value;
  }
  return null;
}

function assertRole(value: unknown, fieldName: string): ReviewRole {
  const role = normalizeString(value);
  if (role === "requester" || role === "provider") return role;
  throw new HttpsError("invalid-argument", `${fieldName} must be requester or provider`);
}

function readRole(value: unknown, fallback: ReviewRole): ReviewRole {
  const role = normalizeString(value);
  return role === "requester" || role === "provider" ? role : fallback;
}

function oppositeRole(role: ReviewRole): ReviewRole {
  return role === "requester" ? "provider" : "requester";
}

function reviewIdFor(
  offerId: string,
  reviewerId: string,
  reviewedUserId: string,
  reviewedRole: ReviewRole,
): string {
  return [offerId, reviewerId, reviewedUserId, reviewedRole]
    .map((part) => encodeURIComponent(part.replaceAll("/", "_")))
    .join("__");
}

function assertRating(value: unknown, fieldName: string): number {
  const rating = Number(value);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new HttpsError("invalid-argument", `${fieldName} must be an integer between 1 and 5`);
  }
  return rating;
}

function readCriteria(rawData: Record<string, unknown>, reviewedRole: ReviewRole): Record<string, number> {
  const rawCriteria = rawData.criteria && typeof rawData.criteria === "object"
    ? rawData.criteria as Record<string, unknown>
    : {};
  const result: Record<string, number> = {};

  if (reviewedRole === "provider") {
    result.communication = assertRating(rawCriteria.communication ?? rawData.communicationRating, "criteria.communication");
    result.punctuality = assertRating(rawCriteria.punctuality ?? rawData.punctualityRating, "criteria.punctuality");
    result.quality = assertRating(rawCriteria.quality ?? rawData.qualityRating, "criteria.quality");
    result.courtesy = rawCriteria.courtesy == null
      ? result.communication
      : assertRating(rawCriteria.courtesy, "criteria.courtesy");
  } else {
    result.communication = assertRating(rawCriteria.communication ?? rawData.communicationRating, "criteria.communication");
    result.punctuality = assertRating(rawCriteria.punctuality ?? rawData.punctualityRating, "criteria.punctuality");
    result.clarity = assertRating(rawCriteria.clarity ?? rawData.qualityRating, "criteria.clarity");
    result.courtesy = rawCriteria.courtesy == null
      ? result.communication
      : assertRating(rawCriteria.courtesy, "criteria.courtesy");
    result.paymentRespect = rawCriteria.paymentRespect == null
      ? result.clarity
      : assertRating(rawCriteria.paymentRespect, "criteria.paymentRespect");
  }
  return result;
}

function averageCriteria(criteria: Record<string, number>): number {
  const values = Object.values(criteria).filter((value) => Number.isFinite(value));
  return values.length === 0
    ? 0
    : Number((values.reduce((sum, value) => sum + value, 0) / values.length).toFixed(3));
}

function analyzeReviewText(rawComment: unknown): {
  comment: string | null;
  flags: ModerationFlags;
  status: ReviewStatus;
} {
  const comment = normalizeString(rawComment).replace(/\s+/g, " ");
  if (comment.length > 500) throw new HttpsError("invalid-argument", "Comment is too long");
  const normalized = normalizeSearchText(comment);
  const containsPersonalData = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(comment)
    || /(?:\+?\d[\s.\-()]*){8,}/.test(comment);
  const containsInsult = ["con", "connard", "connasse", "imbecile", "idiot", "salope", "batard"]
    .some((term) => normalized.includes(term));
  const containsThreat = ["menace", "frapper", "tuer", "casser la gueule", "je vais te retrouver"]
    .some((term) => normalized.includes(term));
  const containsSuspiciousContent = ["escroc", "arnaqueur", "voleur", "fraude", "plainte", "tribunal"]
    .some((term) => normalized.includes(term));
  const flags = {
    containsPersonalData,
    containsInsult,
    containsThreat,
    containsSuspiciousContent,
  };
  return {
    comment: comment || null,
    flags,
    status: Object.values(flags).some(Boolean) ? "pending_moderation" : "pending_peer_review",
  };
}

async function loadListing(offerId: string): Promise<Record<string, unknown>> {
  const snap = await db.collection(COLLECTIONS.listings).doc(offerId).get();
  if (!snap.exists) throw new HttpsError("not-found", "Listing not found");
  return snap.data() ?? {};
}

async function findConversationBetween(
  offerId: string,
  userA: string,
  userB: string,
): Promise<string> {
  const snapshots = await Promise.all(
    ["offerId", "listingId", "offer_id", "listing_id"].map((field) =>
      db.collection(COLLECTIONS.conversations).where(field, "==", offerId).limit(100).get(),
    ),
  );
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      const data = (doc.data() ?? {}) as Record<string, unknown>;
      const participants = readConversationParticipants(data, { conversationId: doc.id });
      if (participants.includes(userA) && participants.includes(userB)) return doc.id;
    }
  }
  throw new HttpsError("permission-denied", "No verified conversation found for this review");
}

async function assertReviewEligibility({
  offerId,
  reviewerId,
  reviewedUserId,
  reviewerRole,
  reviewedRole,
}: {
  offerId: string;
  reviewerId: string;
  reviewedUserId: string;
  reviewerRole: ReviewRole;
  reviewedRole: ReviewRole;
}): Promise<{ listingData: Record<string, unknown>; conversationId: string }> {
  if (reviewerId === reviewedUserId) {
    throw new HttpsError("failed-precondition", "You cannot review yourself");
  }
  if (reviewerRole === reviewedRole) {
    throw new HttpsError("invalid-argument", "Reviews must be reciprocal between requester and provider roles");
  }

  const listingData = await loadListing(offerId);
  const ownerId = readListingOwnerId(listingData);
  if (!ownerId) throw new HttpsError("failed-precondition", "Listing owner is missing");
  if (reviewerRole === "requester" && reviewerId !== ownerId) {
    throw new HttpsError("permission-denied", "Only the listing requester can review the provider");
  }
  if (reviewedRole === "requester" && reviewedUserId !== ownerId) {
    throw new HttpsError("permission-denied", "Only the listing requester can be reviewed as requester");
  }

  const providerId = reviewerRole === "provider" ? reviewerId : reviewedUserId;
  const requesterId = reviewerRole === "requester" ? reviewerId : reviewedUserId;
  const conversationId = await findConversationBetween(offerId, requesterId, providerId);
  return { listingData, conversationId };
}

function isReviewPublicForScore(data: Record<string, unknown>, nowMs = Date.now()): boolean {
  if (data.visibleOnProfile === false || data.isVerified !== true) return false;
  const status = normalizeString(data.status);
  if (status === "published") return true;
  if (status !== "pending_peer_review") return false;
  const publishAfterMs = readTimestampMillis(data.publishAfter);
  return publishAfterMs != null && publishAfterMs <= nowMs;
}

function readReviewForScore(doc: admin.firestore.QueryDocumentSnapshot): ReviewForScore | null {
  const data = (doc.data() ?? {}) as Record<string, unknown>;
  const reviewedRole = readRole(data.reviewedRole, "provider");
  const reviewerRole = readRole(data.reviewerRole, oppositeRole(reviewedRole));
  const source = data.criteria && typeof data.criteria === "object"
    ? data.criteria as Record<string, unknown>
    : {
      communication: Number(data.communicationRating || 0),
      punctuality: Number(data.punctualityRating || 0),
      quality: Number(data.qualityRating || 0),
    };
  const criteria = Object.fromEntries(
    Object.entries(source)
      .map(([key, value]): [string, number] => [key, Number(value || 0)])
      .filter(([, value]) => Number.isFinite(value) && value > 0),
  );
  const averageRating = Number(data.averageRating || data.overallRating || averageCriteria(criteria));
  if (!Number.isFinite(averageRating) || averageRating <= 0) return null;
  return {
    id: doc.id,
    offerId: normalizeString(data.offerId),
    offerTitle: normalizeString(data.offerTitle) || "Annonce iliprestō",
    reviewerId: normalizeString(data.reviewerId),
    reviewedUserId: normalizeString(data.reviewedUserId),
    reviewerRole,
    reviewedRole,
    criteria,
    averageRating,
    reliableWeight: Number(data.reliableWeight || 1),
    comment: normalizeString(data.comment || data.publicComment) || null,
    replyText: normalizeString(data.replyText) || null,
    createdAtMillis: readTimestampMillis(data.createdAt),
    publishedAtMillis: readTimestampMillis(data.publishedAt),
  };
}

function roleSummary(reviews: ReviewForScore[], role: ReviewRole) {
  const roleReviews = reviews.filter((review) => review.reviewedRole === role);
  const count = roleReviews.length;
  const weightedSum = roleReviews.reduce(
    (total, review) => total + review.averageRating * Math.max(0.2, review.reliableWeight || 1),
    0,
  );
  const weightTotal = roleReviews.reduce(
    (total, review) => total + Math.max(0.2, review.reliableWeight || 1),
    0,
  );
  const average = weightTotal === 0 ? 0 : Number((weightedSum / weightTotal).toFixed(3));
  const reliableAverage = count === 0
    ? 0
    : Number(((PLATFORM_DEFAULT_AVERAGE * BAYESIAN_MIN_REVIEWS + weightedSum)
      / (BAYESIAN_MIN_REVIEWS + weightTotal)).toFixed(3));
  const score100 = count === 0 ? 50 : Math.round((reliableAverage / 5) * 100);
  const criteriaTotals = new Map<string, { total: number; count: number }>();
  for (const review of roleReviews) {
    for (const [key, value] of Object.entries(review.criteria)) {
      const existing = criteriaTotals.get(key) ?? { total: 0, count: 0 };
      criteriaTotals.set(key, { total: existing.total + value, count: existing.count + 1 });
    }
  }
  const criteriaAverages = Object.fromEntries(
    Array.from(criteriaTotals.entries())
      .map(([key, value]) => [key, Number((value.total / value.count).toFixed(3))]),
  );
  const badges: string[] = [];
  if (count === 0) badges.push("new_profile");
  if (count >= 1) badges.push("verified_reviews_ilipresto");
  if (count >= 3 && reliableAverage >= 4.35) {
    badges.push(role === "provider" ? "top_provider" : "reliable_requester");
  }
  if (count >= 3 && Number(criteriaAverages.communication || 0) >= 4.5) {
    badges.push("top_communication");
  }
  if (count >= 3 && Number(criteriaAverages.punctuality || 0) >= 4.5) {
    badges.push("punctual");
  }
  if (count >= 3 && Number(criteriaAverages.quality || criteriaAverages.clarity || 0) >= 4.5) {
    badges.push(role === "provider" ? "recommended_quality" : "clear_requester");
  }
  return {
    role,
    roleLabel: role === "provider" ? "prestataire" : "annonceur",
    average,
    reliableAverage,
    score100,
    reviewsCount: count,
    publishedReviewsCount: count,
    criteriaAverages,
    badges,
  };
}

async function recalculateSecureTrustScore(userId: string): Promise<{
  trustScore: Record<string, unknown>;
  trustScoreV2: Record<string, unknown>;
}> {
  const [userSnap, reviewsSnap] = await Promise.all([
    db.collection(COLLECTIONS.users).doc(userId).get(),
    db.collection(REVIEWS_COLLECTION).where("reviewedUserId", "==", userId).get(),
  ]);
  const reviews: ReviewForScore[] = [];
  let pendingReviewsCount = 0;
  for (const doc of reviewsSnap.docs) {
    const data = (doc.data() ?? {}) as Record<string, unknown>;
    const status = normalizeString(data.status);
    if (status === "pending_peer_review" || status === "pending_moderation") pendingReviewsCount += 1;
    if (!isReviewPublicForScore(data)) continue;
    const parsed = readReviewForScore(doc);
    if (parsed) reviews.push(parsed);
  }

  const provider = roleSummary(reviews, "provider");
  const requester = roleSummary(reviews, "requester");
  const totalReviews = reviews.length;
  const globalAverage = totalReviews === 0
    ? 0
    : Number((reviews.reduce((total, review) => total + review.averageRating, 0) / totalReviews).toFixed(3));
  const userData = userSnap.data() ?? {};
  const profileVerified = userData.isProfileVerified === true
    || userData.isVerified === true
    || userData.verified === true;
  const profileCompletenessBonus = profileVerified ? 8 : 0;
  const score100 = Math.max(
    0,
    Math.min(100, Math.round((provider.score100 * 0.65) + (requester.score100 * 0.35) + profileCompletenessBonus)),
  );
  const lastReviewAtMillis = reviews
    .map((review) => review.publishedAtMillis ?? review.createdAtMillis)
    .filter((value): value is number => typeof value === "number")
    .sort((a, b) => b - a)[0] ?? null;

  const trustScoreV2 = {
    provider,
    requester,
    global: {
      average: globalAverage,
      reliableAverage: totalReviews === 0
        ? 0
        : Number(((provider.reliableAverage * provider.reviewsCount
          + requester.reliableAverage * requester.reviewsCount) / totalReviews).toFixed(3)),
      reviewsCount: totalReviews,
      score100,
      profileVerified,
      lastReviewAt: lastReviewAtMillis == null
        ? null
        : admin.firestore.Timestamp.fromMillis(lastReviewAtMillis),
    },
  };

  const combinedCriteria = {
    ...provider.criteriaAverages,
    ...requester.criteriaAverages,
  } as Record<string, number>;
  const badges = Array.from(new Set([...provider.badges, ...requester.badges]));
  const trustScore = {
    average: globalAverage,
    communicationAverage: Number(combinedCriteria.communication || 0),
    punctualityAverage: Number(combinedCriteria.punctuality || 0),
    qualityAverage: Number(combinedCriteria.quality || combinedCriteria.clarity || 0),
    reviewsCount: totalReviews,
    publishedReviewsCount: totalReviews,
    pendingReviewsCount,
    firstReviewAt: null,
    lastReviewAt: lastReviewAtMillis == null
      ? null
      : admin.firestore.Timestamp.fromMillis(lastReviewAtMillis),
    paidShowcaseActive: false,
    badges: badges.length === 0 ? ["new_profile"] : badges,
  };

  await Promise.all([
    db.collection(TRUST_SCORES_V2_COLLECTION).doc(userId).set({
      userId,
      trustScoreV2,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }),
    db.collection(COLLECTIONS.users).doc(userId).set({
      trustScore,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true }),
  ]);
  return { trustScore, trustScoreV2 };
}

async function publishReciprocalReviewsIfReady(
  offerId: string,
  reviewerId: string,
  reviewedUserId: string,
): Promise<void> {
  const [counterpartSnap, currentSnap] = await Promise.all([
    db.collection(REVIEWS_COLLECTION)
      .where("offerId", "==", offerId)
      .where("reviewerId", "==", reviewedUserId)
      .where("reviewedUserId", "==", reviewerId)
      .limit(5)
      .get(),
    db.collection(REVIEWS_COLLECTION)
      .where("offerId", "==", offerId)
      .where("reviewerId", "==", reviewerId)
      .where("reviewedUserId", "==", reviewedUserId)
      .limit(5)
      .get(),
  ]);
  const counterpartIds = counterpartSnap.docs
    .filter((doc) => normalizeString(doc.data().status) === "pending_peer_review")
    .map((doc) => doc.id);
  if (counterpartIds.length === 0) return;
  const currentIds = currentSnap.docs
    .filter((doc) => normalizeString(doc.data().status) === "pending_peer_review")
    .map((doc) => doc.id);
  const ids = Array.from(new Set([...counterpartIds, ...currentIds]));
  if (ids.length < 2) return;
  const batch = db.batch();
  for (const id of ids) {
    batch.set(db.collection(REVIEWS_COLLECTION).doc(id), {
      status: "published",
      visibleOnProfile: true,
      publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await batch.commit();
}

async function listConversationResponders(
  offerId: string,
  ownerId: string,
): Promise<Array<{
  userId: string;
  responseAtMillis: number | null;
  conversationId: string;
}>> {
  const snapshots = await Promise.all(
    ["offerId", "listingId", "offer_id", "listing_id"].map((field) =>
      db.collection(COLLECTIONS.conversations).where(field, "==", offerId).limit(100).get(),
    ),
  );
  const byUserId = new Map<string, { userId: string; responseAtMillis: number | null; conversationId: string }>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      const data = (doc.data() ?? {}) as Record<string, unknown>;
      const participants = readConversationParticipants(data, { conversationId: doc.id });
      if (!participants.includes(ownerId)) continue;
      const responseAtMillis = readTimestampMillis(data.createdAt)
        ?? readTimestampMillis(data.lastMessageAt)
        ?? readTimestampMillis(data.updatedAt)
        ?? null;
      for (const participantId of participants) {
        if (!participantId || participantId === ownerId) continue;
        const existing = byUserId.get(participantId);
        if (existing && (existing.responseAtMillis ?? Number.MAX_SAFE_INTEGER)
          <= (responseAtMillis ?? Number.MAX_SAFE_INTEGER)) continue;
        byUserId.set(participantId, {
          userId: participantId,
          responseAtMillis,
          conversationId: doc.id,
        });
      }
    }
  }
  return Array.from(byUserId.values());
}

export const getEligibleRespondersForReviewV2 = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const ownerId = requireAuthUid(request);
    const offerId = normalizeString(request.data?.offerId || request.data?.listingId);
    if (!offerId) throw new HttpsError("invalid-argument", "offerId is required");
    try {
      const listingData = await loadListing(offerId);
      if (readListingOwnerId(listingData) !== ownerId) {
        throw new HttpsError("permission-denied", "You do not own this listing");
      }
      const candidates = await listConversationResponders(offerId, ownerId);
      const responders = [];
      for (const candidate of candidates) {
        const v2Id = reviewIdFor(offerId, ownerId, candidate.userId, "provider");
        const legacyId = [offerId, ownerId, candidate.userId]
          .map((part) => encodeURIComponent(part.replaceAll("/", "_")))
          .join("__");
        const [v2Snap, legacySnap, userSnap] = await Promise.all([
          db.collection(REVIEWS_COLLECTION).doc(v2Id).get(),
          db.collection(REVIEWS_COLLECTION).doc(legacyId).get(),
          db.collection(COLLECTIONS.users).doc(candidate.userId).get(),
        ]);
        if (v2Snap.exists || legacySnap.exists) continue;
        const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
        responders.push({
          userId: candidate.userId,
          pseudo: readDisplayName(userData),
          photoUrl: readPhotoUrl(userData),
          city: readCity(userData),
          responseAtMillis: candidate.responseAtMillis,
          conversationId: candidate.conversationId,
          badge: "A répondu à cette annonce",
        });
      }
      responders.sort((a, b) => (a.responseAtMillis ?? 0) - (b.responseAtMillis ?? 0));
      return { ok: true, responders };
    } catch (error) {
      throw toHttpsError(error, "Unable to load eligible responders v2");
    }
  },
);

export const getPendingReviewTasksV2 = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const userId = requireAuthUid(request);
    try {
      const tasks: Array<Record<string, unknown>> = [];
      const [receivedSnap, authoredSnap, ownerListings] = await Promise.all([
        db.collection(REVIEWS_COLLECTION).where("reviewedUserId", "==", userId).get(),
        db.collection(REVIEWS_COLLECTION).where("reviewerId", "==", userId).get(),
        db.collection(COLLECTIONS.listings).where("ownerId", "==", userId).limit(120).get(),
      ]);

      for (const doc of authoredSnap.docs) {
        const data = (doc.data() ?? {}) as Record<string, unknown>;
        if (data.correctionRequested !== true || normalizeString(data.status) !== "pending_moderation") continue;
        tasks.push({
          taskId: `correction:${doc.id}`,
          type: "correction" satisfies PendingReviewTaskType,
          reviewId: doc.id,
          offerId: normalizeString(data.offerId),
          offerTitle: normalizeString(data.offerTitle) || "Annonce iliprestō",
          reviewedUserId: normalizeString(data.reviewedUserId),
          conversationId: normalizeString(data.conversationId || data.responderConversationId),
          comment: normalizeString(data.comment || data.publicComment),
          correctionMessage: normalizeString(data.correctionMessage)
            || "Merci de corriger votre avis avant publication.",
          createdAtMillis: readTimestampMillis(data.createdAt),
        });
      }

      for (const doc of receivedSnap.docs) {
        const data = (doc.data() ?? {}) as Record<string, unknown>;
        const sourceStatus = normalizeString(data.status);
        if (sourceStatus !== "pending_peer_review" && sourceStatus !== "published") continue;
        const sourceReviewerRole = readRole(data.reviewerRole, "requester");
        const sourceReviewedRole = readRole(data.reviewedRole, "provider");
        if (sourceReviewerRole !== "requester" || sourceReviewedRole !== "provider") continue;
        const requesterId = normalizeString(data.reviewerId);
        const offerId = normalizeString(data.offerId);
        if (!requesterId || !offerId) continue;
        const counterpartId = reviewIdFor(offerId, userId, requesterId, "requester");
        const counterpartSnap = await db.collection(REVIEWS_COLLECTION).doc(counterpartId).get();
        if (counterpartSnap.exists) continue;
        const createdAtMillis = readTimestampMillis(data.createdAt);
        if (createdAtMillis != null
          && createdAtMillis + REVIEW_WINDOW_DAYS * 24 * 60 * 60 * 1000 < Date.now()) continue;
        const requesterSnap = await db.collection(COLLECTIONS.users).doc(requesterId).get();
        const requesterData = (requesterSnap.data() ?? {}) as Record<string, unknown>;
        tasks.push({
          taskId: `reciprocal:${doc.id}`,
          type: "reciprocal" satisfies PendingReviewTaskType,
          sourceReviewId: doc.id,
          offerId,
          offerTitle: normalizeString(data.offerTitle) || "Annonce iliprestō",
          reviewedUserId: requesterId,
          reviewedUserName: readDisplayName(requesterData, "Annonceur iliprestō"),
          reviewedUserPhotoUrl: readPhotoUrl(requesterData),
          reviewedUserCity: readCity(requesterData),
          conversationId: normalizeString(data.conversationId || data.responderConversationId),
          reviewerRole: "provider",
          reviewedRole: "requester",
          createdAtMillis,
          dueAtMillis: createdAtMillis == null
            ? null
            : createdAtMillis + REVIEW_WINDOW_DAYS * 24 * 60 * 60 * 1000,
        });
      }

      for (const doc of ownerListings.docs) {
        const data = (doc.data() ?? {}) as Record<string, unknown>;
        if (data.reviewRequested !== true || data.reviewSubmitted === true || data.reviewDismissed === true) continue;
        const existing = await db.collection(REVIEWS_COLLECTION)
          .where("offerId", "==", doc.id)
          .where("reviewerId", "==", userId)
          .limit(1)
          .get();
        if (!existing.empty) continue;
        tasks.push({
          taskId: `rate_later:${doc.id}`,
          type: "rate_later" satisfies PendingReviewTaskType,
          offerId: doc.id,
          offerTitle: normalizeString(data.title || data.titre) || "Annonce iliprestō",
          conversationId: "",
          reviewerRole: "requester",
          reviewedRole: "provider",
          createdAtMillis: readTimestampMillis(data.closedAt || data.deletedAt || data.updatedAt),
        });
      }

      tasks.sort((a, b) => Number(b.createdAtMillis || 0) - Number(a.createdAtMillis || 0));
      return { ok: true, tasks, count: tasks.length };
    } catch (error) {
      throw toHttpsError(error, "Unable to load pending review tasks v2");
    }
  },
);

export const submitMutualVerifiedReviewComplete = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const reviewerId = requireAuthUid(request);
    const offerId = normalizeString(request.data?.offerId || request.data?.listingId);
    const reviewedUserId = normalizeString(request.data?.reviewedUserId);
    const reviewerRole = assertRole(request.data?.reviewerRole, "reviewerRole");
    const reviewedRole = assertRole(request.data?.reviewedRole, "reviewedRole");
    if (!offerId || !reviewedUserId) {
      throw new HttpsError("invalid-argument", "offerId and reviewedUserId are required");
    }
    if (request.data?.confirmationChecked !== true) {
      throw new HttpsError("failed-precondition", "Experience confirmation is required");
    }
    const rateAllowed = await canProceedRateLimited(
      "verified_review_v2_complete_submit",
      reviewerId,
      20,
      24 * 60 * 60 * 1000,
    );
    if (!rateAllowed) throw new HttpsError("resource-exhausted", "Too many reviews submitted today");

    try {
      const { listingData, conversationId } = await assertReviewEligibility({
        offerId,
        reviewerId,
        reviewedUserId,
        reviewerRole,
        reviewedRole,
      });
      const criteria = readCriteria(request.data ?? {}, reviewedRole);
      const averageRating = averageCriteria(criteria);
      const moderation = analyzeReviewText(request.data?.comment ?? request.data?.publicComment);
      const privateFeedback = normalizeString(request.data?.privateFeedback).slice(0, 800) || null;
      const wouldRecommend = request.data?.wouldRecommend == null
        ? averageRating >= 4
        : request.data?.wouldRecommend === true;
      const reviewId = reviewIdFor(offerId, reviewerId, reviewedUserId, reviewedRole);
      const reviewRef = db.collection(REVIEWS_COLLECTION).doc(reviewId);
      const now = admin.firestore.FieldValue.serverTimestamp();
      const publishAfter = admin.firestore.Timestamp.fromMillis(
        Date.now() + REVIEW_WINDOW_DAYS * 24 * 60 * 60 * 1000,
      );

      await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(reviewRef);
        if (existing.exists) {
          throw new HttpsError("already-exists", "A review already exists for this listing, user and role");
        }
        transaction.set(reviewRef, {
          reviewId,
          offerId,
          offerTitle: normalizeString(listingData.title || listingData.titre) || "Annonce iliprestō",
          offerOwnerId: readListingOwnerId(listingData),
          reviewerId,
          reviewedUserId,
          reviewerRole,
          reviewedRole,
          criteria,
          communicationRating: Number(criteria.communication || 0),
          punctualityRating: Number(criteria.punctuality || 0),
          qualityRating: Number(criteria.quality || criteria.clarity || 0),
          averageRating,
          overallRating: averageRating,
          reliableWeight: 1,
          wouldRecommend,
          comment: moderation.comment,
          publicComment: moderation.comment,
          privateFeedback,
          status: moderation.status,
          isVerified: true,
          verificationType: "mutual_offer_conversation",
          confirmationChecked: true,
          responderConversationId: conversationId,
          conversationId,
          publishAfter,
          reviewWindowDays: REVIEW_WINDOW_DAYS,
          createdAt: now,
          updatedAt: null,
          publishedAt: null,
          moderationFlags: moderation.flags,
          reportCount: 0,
          disputeCount: 0,
          visibleOnProfile: false,
          correctionRequested: false,
          ratingSchemaVersion: 2,
          flowVersion: "complete_mutual_v2",
        });
        if (reviewerRole === "requester" && reviewedRole === "provider") {
          transaction.set(db.collection(COLLECTIONS.listings).doc(offerId), {
            selectedUserId: reviewedUserId,
            reviewRequested: true,
            reviewSubmitted: true,
            reviewDismissed: false,
            updatedAt: now,
          }, { merge: true });
        }
      });

      if (moderation.status === "pending_peer_review") {
        await publishReciprocalReviewsIfReady(offerId, reviewerId, reviewedUserId);
      }
      const finalSnap = await reviewRef.get();
      const finalStatus = normalizeString(finalSnap.data()?.status) || moderation.status;
      const [reviewedScore, reviewerScore] = await Promise.all([
        recalculateSecureTrustScore(reviewedUserId),
        recalculateSecureTrustScore(reviewerId),
      ]);

      const reciprocalRequested = reviewerRole === "requester"
        && reviewedRole === "provider"
        && finalStatus !== "pending_moderation";
      await createInAppNotification({
        notificationId: `mutual_review_complete_${reviewId}`,
        userId: reviewedUserId,
        title: reciprocalRequested
          ? "À votre tour de noter l’annonceur"
          : finalStatus === "pending_moderation"
            ? "Un avis vous concernant est en cours de vérification"
            : "Vous avez reçu un nouvel avis vérifié",
        message: reciprocalRequested
          ? "Ouvrez Mes avis pour noter l’annonceur. Les deux avis seront publiés ensemble."
          : finalStatus === "published"
            ? "L’avis est publié et votre Score Confiance a été recalculé."
            : "L’avis sera publié à la fin du délai prévu s’il n’est pas complété avant.",
        type: reciprocalRequested ? "review_action_required" : "verified_review_received",
        routeName: reciprocalRequested ? "/account/mes-avis" : `/profile/${encodeURIComponent(reviewedUserId)}`,
        offerId,
        data: {
          reviewId,
          status: finalStatus,
          conversationId,
          actionRequired: reciprocalRequested,
          ratingSchemaVersion: 2,
        },
      });

      logger.info("marketplace_mutual_review_complete_submitted", {
        offerId,
        reviewId,
        reviewerId,
        reviewedUserId,
        reviewerRole,
        reviewedRole,
        finalStatus,
      });
      return {
        ok: true,
        reviewId,
        status: finalStatus,
        averageRating,
        trustScore: reviewedScore.trustScore,
        trustScoreV2: reviewedScore.trustScoreV2,
        reviewerTrustScoreV2: reviewerScore.trustScoreV2,
      };
    } catch (error) {
      throw toHttpsError(error, "Unable to submit complete mutual verified review");
    }
  },
);

export const reviseReviewV2 = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const reviewerId = requireAuthUid(request);
    const reviewId = normalizeString(request.data?.reviewId);
    const comment = normalizeString(request.data?.comment);
    if (!reviewId) throw new HttpsError("invalid-argument", "reviewId is required");
    try {
      const ref = db.collection(REVIEWS_COLLECTION).doc(reviewId);
      const snap = await ref.get();
      if (!snap.exists) throw new HttpsError("not-found", "Review not found");
      const data = (snap.data() ?? {}) as Record<string, unknown>;
      if (normalizeString(data.reviewerId) !== reviewerId) {
        throw new HttpsError("permission-denied", "Only the review author can revise this review");
      }
      if (data.correctionRequested !== true || normalizeString(data.status) !== "pending_moderation") {
        throw new HttpsError("failed-precondition", "This review is not awaiting correction");
      }
      const moderation = analyzeReviewText(comment);
      await ref.set({
        comment: moderation.comment,
        publicComment: moderation.comment,
        moderationFlags: moderation.flags,
        status: moderation.status,
        correctionRequested: false,
        correctionMessage: null,
        correctedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      if (moderation.status === "pending_peer_review") {
        await publishReciprocalReviewsIfReady(
          normalizeString(data.offerId),
          reviewerId,
          normalizeString(data.reviewedUserId),
        );
      }
      const finalSnap = await ref.get();
      const finalStatus = normalizeString(finalSnap.data()?.status) || moderation.status;
      await recalculateSecureTrustScore(normalizeString(data.reviewedUserId));
      return { ok: true, reviewId, status: finalStatus };
    } catch (error) {
      throw toHttpsError(error, "Unable to revise review v2");
    }
  },
);

export const dismissPendingReviewTaskV2 = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const userId = requireAuthUid(request);
    const offerId = normalizeString(request.data?.offerId);
    if (!offerId) throw new HttpsError("invalid-argument", "offerId is required");
    try {
      const ref = db.collection(COLLECTIONS.listings).doc(offerId);
      const snap = await ref.get();
      if (!snap.exists) throw new HttpsError("not-found", "Listing not found");
      if (readListingOwnerId(snap.data() ?? {}) !== userId) {
        throw new HttpsError("permission-denied", "You do not own this listing");
      }
      await ref.set({
        reviewRequested: false,
        reviewDismissed: true,
        reviewDismissedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return { ok: true };
    } catch (error) {
      throw toHttpsError(error, "Unable to dismiss pending review task v2");
    }
  },
);

export const getUserTrustScoreV2Complete = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const userId = normalizeString(request.data?.userId);
    if (!userId) throw new HttpsError("invalid-argument", "userId is required");
    try {
      const { trustScore, trustScoreV2 } = await recalculateSecureTrustScore(userId);
      const reviewsSnap = await db.collection(REVIEWS_COLLECTION).where("reviewedUserId", "==", userId).get();
      const latestReviews = reviewsSnap.docs
        .filter((doc) => isReviewPublicForScore((doc.data() ?? {}) as Record<string, unknown>))
        .map(readReviewForScore)
        .filter((review): review is ReviewForScore => review != null)
        .sort((a, b) => (b.publishedAtMillis ?? b.createdAtMillis ?? 0)
          - (a.publishedAtMillis ?? a.createdAtMillis ?? 0))
        .slice(0, 12)
        .map((review) => ({
          id: review.id,
          reviewId: review.id,
          offerId: review.offerId,
          offerTitle: review.offerTitle,
          averageRating: review.averageRating,
          criteria: review.criteria,
          comment: review.comment,
          replyText: review.replyText,
          reviewerRole: review.reviewerRole,
          reviewedRole: review.reviewedRole,
          roleLabel: review.reviewedRole === "provider" ? "prestataire" : "annonceur",
          createdAtMillis: review.createdAtMillis,
          publishedAtMillis: review.publishedAtMillis,
        }));
      return {
        ok: true,
        ratingsV2Enabled: true,
        ratingsPaidShowcaseEnabled: false,
        canonicalStorage: TRUST_SCORES_V2_COLLECTION,
        trustScore,
        trustScoreV2,
        latestReviews,
      };
    } catch (error) {
      throw toHttpsError(error, "Unable to load complete trust score v2");
    }
  },
);
