import admin from "../../../core/firebase_admin_compat";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { readConversationParticipants } from "../../messaging/participants";
import { createInAppNotification } from "../../notifications/push";
import { toHttpsError } from "../services/errors";

const REVIEWS_COLLECTION = "reviews";
const REVIEW_REPORTS_COLLECTION = "review_reports";
const REVIEW_REPLIES_COLLECTION = "review_replies";
const REVIEW_WINDOW_DAYS = 14;
const JOB_DONE_OVERLAY_HOURS = 10;
const BAYESIAN_MIN_REVIEWS = 10;
const PLATFORM_DEFAULT_AVERAGE = 4.2;

export const ratingsV2Enabled = true;

type ReviewRole = "requester" | "provider";
type ReviewStatus = "published" | "pending_peer_review" | "pending_moderation" | "rejected" | "disputed" | "hidden";

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

function readListingOwnerId(data: Record<string, unknown>): string {
  return normalizeString(data.ownerId) || normalizeString(data.userId) || normalizeString(data.uid);
}

function readTimestampMillis(value: unknown): number | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}

function readRole(value: unknown, fallback: ReviewRole): ReviewRole {
  const role = normalizeString(value);
  return role === "requester" || role === "provider" ? role : fallback;
}

function assertRole(value: unknown, fieldName: string): ReviewRole {
  const role = normalizeString(value);
  if (role === "requester" || role === "provider") return role;
  throw new HttpsError("invalid-argument", `${fieldName} must be requester or provider`);
}

function oppositeRole(role: ReviewRole): ReviewRole {
  return role === "requester" ? "provider" : "requester";
}

function reviewIdFor(offerId: string, reviewerId: string, reviewedUserId: string, reviewedRole: ReviewRole): string {
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
  const legacyCommunication = rawData.communicationRating;
  const legacyPunctuality = rawData.punctualityRating;
  const legacyQuality = rawData.qualityRating;
  const result: Record<string, number> = {};

  if (reviewedRole === "provider") {
    result.communication = assertRating(rawCriteria.communication ?? legacyCommunication, "criteria.communication");
    result.punctuality = assertRating(rawCriteria.punctuality ?? legacyPunctuality, "criteria.punctuality");
    result.quality = assertRating(rawCriteria.quality ?? legacyQuality, "criteria.quality");
    result.courtesy = rawCriteria.courtesy == null ? result.communication : assertRating(rawCriteria.courtesy, "criteria.courtesy");
  } else {
    result.communication = assertRating(rawCriteria.communication ?? legacyCommunication, "criteria.communication");
    result.punctuality = assertRating(rawCriteria.punctuality ?? legacyPunctuality, "criteria.punctuality");
    result.clarity = assertRating(rawCriteria.clarity ?? legacyQuality, "criteria.clarity");
    result.courtesy = rawCriteria.courtesy == null ? result.communication : assertRating(rawCriteria.courtesy, "criteria.courtesy");
    result.paymentRespect = rawCriteria.paymentRespect == null ? result.clarity : assertRating(rawCriteria.paymentRespect, "criteria.paymentRespect");
  }
  return result;
}

function averageCriteria(criteria: Record<string, number>): number {
  const values = Object.values(criteria).filter((value) => Number.isFinite(value));
  return values.length === 0 ? 0 : Number((values.reduce((sum, value) => sum + value, 0) / values.length).toFixed(3));
}

function analyzeReviewText(rawComment: unknown): { comment: string | null; flags: ModerationFlags; status: ReviewStatus } {
  const comment = normalizeString(rawComment).replace(/\s+/g, " ");
  if (comment.length > 500) throw new HttpsError("invalid-argument", "Comment is too long");
  const normalized = normalizeSearchText(comment);
  const containsPersonalData = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(comment)
    || /(?:\+?\d[\s.\-()]*){8,}/.test(comment);
  const containsInsult = ["con", "connard", "connasse", "imbecile", "idiot", "salope", "batard"].some((term) => normalized.includes(term));
  const containsThreat = ["menace", "frapper", "tuer", "casser la gueule", "je vais te retrouver"].some((term) => normalized.includes(term));
  const containsSuspiciousContent = ["escroc", "arnaqueur", "voleur", "fraude", "plainte", "tribunal"].some((term) => normalized.includes(term));
  const flags = { containsPersonalData, containsInsult, containsThreat, containsSuspiciousContent };
  return {
    comment: comment || null,
    flags,
    status: Object.values(flags).some(Boolean) ? "pending_moderation" : "pending_peer_review",
  };
}

async function loadListing(offerId: string): Promise<Record<string, unknown>> {
  const listingSnap = await db.collection(COLLECTIONS.listings).doc(offerId).get();
  if (!listingSnap.exists) throw new HttpsError("not-found", "Listing not found");
  return listingSnap.data() ?? {};
}

async function findConversationBetween(offerId: string, userA: string, userB: string): Promise<string> {
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
}): Promise<{ listingData: Record<string, unknown>; ownerId: string; conversationId: string }> {
  if (reviewerId === reviewedUserId) throw new HttpsError("failed-precondition", "You cannot review yourself");
  if (reviewerRole === reviewedRole) throw new HttpsError("invalid-argument", "Reviews must be reciprocal between requester and provider roles");

  const listingData = await loadListing(offerId);
  const ownerId = readListingOwnerId(listingData);
  if (!ownerId) throw new HttpsError("failed-precondition", "Listing owner is missing");
  if (reviewerRole === "requester" && reviewerId !== ownerId) throw new HttpsError("permission-denied", "Only the listing requester can review the provider as requester");
  if (reviewedRole === "requester" && reviewedUserId !== ownerId) throw new HttpsError("permission-denied", "Only the listing requester can be reviewed as requester");

  const providerId = reviewerRole === "provider" ? reviewerId : reviewedUserId;
  const requesterId = reviewerRole === "requester" ? reviewerId : reviewedUserId;
  const conversationId = await findConversationBetween(offerId, requesterId, providerId);
  return { listingData, ownerId, conversationId };
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
  const criteriaSource = data.criteria && typeof data.criteria === "object"
    ? data.criteria as Record<string, unknown>
    : {
      communication: Number(data.communicationRating || 0),
      punctuality: Number(data.punctualityRating || 0),
      quality: Number(data.qualityRating || 0),
    };
  const criteria = Object.fromEntries(
    Object.entries(criteriaSource)
      .map(
        ([key, value]): [string, number] => [
          key,
          Number(value || 0),
        ],
      )
      .filter(
        ([, value]) => Number.isFinite(value) && value > 0,
      ),
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

function roleLabel(role: ReviewRole): string {
  return role === "provider" ? "prestataire" : "annonceur";
}

function summarizeRole(reviews: ReviewForScore[], role: ReviewRole) {
  const roleReviews = reviews.filter((review) => review.reviewedRole === role);
  const count = roleReviews.length;
  const weightedSum = roleReviews.reduce((total, review) => total + review.averageRating * Math.max(0.2, review.reliableWeight || 1), 0);
  const weightTotal = roleReviews.reduce((total, review) => total + Math.max(0.2, review.reliableWeight || 1), 0);
  const average = weightTotal === 0 ? 0 : Number((weightedSum / weightTotal).toFixed(3));
  const reliableAverage = count === 0 ? 0 : Number(((PLATFORM_DEFAULT_AVERAGE * BAYESIAN_MIN_REVIEWS + weightedSum) / (BAYESIAN_MIN_REVIEWS + weightTotal)).toFixed(3));
  const score100 = count === 0 ? 50 : Math.round((reliableAverage / 5) * 100);
  const criteriaTotals = new Map<string, { total: number; count: number }>();
  for (const review of roleReviews) {
    for (const [key, value] of Object.entries(review.criteria)) {
      const existing = criteriaTotals.get(key) ?? { total: 0, count: 0 };
      criteriaTotals.set(key, { total: existing.total + value, count: existing.count + 1 });
    }
  }
  const criteriaAverages = Object.fromEntries(Array.from(criteriaTotals.entries()).map(([key, value]) => [key, Number((value.total / value.count).toFixed(3))]));
  const badges: string[] = [];
  if (count === 0) badges.push("new_profile");
  if (count >= 1) badges.push("verified_reviews_ilipresto");
  if (count >= 3 && reliableAverage >= 4.35) badges.push(role === "provider" ? "top_provider" : "reliable_requester");
  if (count >= 3 && Number(criteriaAverages.communication || 0) >= 4.5) badges.push("top_communication");
  if (count >= 3 && Number(criteriaAverages.punctuality || 0) >= 4.5) badges.push("punctual");
  if (count >= 3 && Number(criteriaAverages.quality || criteriaAverages.clarity || 0) >= 4.5) badges.push(role === "provider" ? "recommended_quality" : "clear_requester");
  return { role, roleLabel: roleLabel(role), average, reliableAverage, score100, reviewsCount: count, publishedReviewsCount: count, criteriaAverages, badges };
}

function summarizeTrustScoreV2(reviews: ReviewForScore[], userData: Record<string, unknown>) {
  const provider = summarizeRole(reviews, "provider");
  const requester = summarizeRole(reviews, "requester");
  const totalReviews = reviews.length;
  const globalAverage = totalReviews === 0 ? 0 : Number((reviews.reduce((total, review) => total + review.averageRating, 0) / totalReviews).toFixed(3));
  const profileVerified = userData.isProfileVerified === true || userData.isVerified === true || userData.verified === true;
  const profileCompletenessBonus = profileVerified ? 8 : 0;
  const score100 = Math.max(0, Math.min(100, Math.round((provider.score100 * 0.65) + (requester.score100 * 0.35) + profileCompletenessBonus)));
  const lastReviewAtMillis = reviews.map((review) => review.publishedAtMillis ?? review.createdAtMillis).filter((value): value is number => typeof value === "number").sort((a, b) => b - a)[0] ?? null;
  return {
    provider,
    requester,
    global: {
      average: globalAverage,
      reliableAverage: totalReviews === 0 ? 0 : Number(((provider.reliableAverage * provider.reviewsCount + requester.reliableAverage * requester.reviewsCount) / totalReviews).toFixed(3)),
      reviewsCount: totalReviews,
      score100,
      profileVerified,
      lastReviewAt: lastReviewAtMillis == null ? null : admin.firestore.Timestamp.fromMillis(lastReviewAtMillis),
    },
  };
}

function legacyTrustScoreFromV2(scoreV2: ReturnType<typeof summarizeTrustScoreV2>) {
  const allCriteria = { ...scoreV2.provider.criteriaAverages, ...scoreV2.requester.criteriaAverages } as Record<string, number>;
  const reviewsCount = scoreV2.global.reviewsCount;
  const badges = Array.from(new Set([...scoreV2.provider.badges, ...scoreV2.requester.badges]));
  return {
    average: scoreV2.global.average,
    communicationAverage: Number(allCriteria.communication || 0),
    punctualityAverage: Number(allCriteria.punctuality || 0),
    qualityAverage: Number(allCriteria.quality || allCriteria.clarity || 0),
    reviewsCount,
    publishedReviewsCount: reviewsCount,
    pendingReviewsCount: 0,
    firstReviewAt: null,
    lastReviewAt: scoreV2.global.lastReviewAt,
    paidShowcaseActive: false,
    badges: badges.length === 0 ? ["new_profile"] : badges,
  };
}

async function recalculateUserTrustScoreV2(userId: string): Promise<Record<string, unknown>> {
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
    const review = readReviewForScore(doc);
    if (review) reviews.push(review);
  }
  const trustScoreV2 = summarizeTrustScoreV2(reviews, userSnap.data() ?? {});
  const trustScore = { ...legacyTrustScoreFromV2(trustScoreV2), pendingReviewsCount };
  await db.collection(COLLECTIONS.users).doc(userId).set({ trustScore, trustScoreV2, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  return { trustScore, trustScoreV2 };
}

async function publishReciprocalReviewsIfReady(offerId: string, reviewerId: string, reviewedUserId: string): Promise<void> {
  const counterpartSnap = await db.collection(REVIEWS_COLLECTION).where("offerId", "==", offerId).where("reviewerId", "==", reviewedUserId).where("reviewedUserId", "==", reviewerId).limit(5).get();
  const reviewIds = counterpartSnap.docs.filter((doc) => normalizeString(doc.data().status) === "pending_peer_review").map((doc) => doc.id);
  if (reviewIds.length === 0) return;
  const currentSnap = await db.collection(REVIEWS_COLLECTION).where("offerId", "==", offerId).where("reviewerId", "==", reviewerId).where("reviewedUserId", "==", reviewedUserId).limit(5).get();
  for (const doc of currentSnap.docs) if (normalizeString(doc.data().status) === "pending_peer_review") reviewIds.push(doc.id);
  const batch = db.batch();
  for (const reviewId of Array.from(new Set(reviewIds))) {
    batch.set(db.collection(REVIEWS_COLLECTION).doc(reviewId), { status: "published", visibleOnProfile: true, publishedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }
  await batch.commit();
}

function requesterFoundProviderUpdate(reviewedUserId: string, reason: string) {
  const visibleUntil = admin.firestore.Timestamp.fromDate(new Date(Date.now() + JOB_DONE_OVERLAY_HOURS * 60 * 60 * 1000));
  const now = admin.firestore.FieldValue.serverTimestamp();
  return {
    status: "active",
    visibility: "public",
    isActive: true,
    isPublished: true,
    selectedUserId: reviewedUserId,
    closedReason: reason,
    deletedReason: reason,
    archiveReason: reason,
    closedAt: now,
    deletedAt: now,
    reviewRequested: true,
    reviewSubmitted: true,
    jobDoneOverlayVisible: true,
    jobDoneOverlayVisibleUntil: visibleUntil,
    removeFromBrowseAt: visibleUntil,
    updatedAt: now,
  };
}

export const submitMutualVerifiedReview = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const reviewerId = requireAuthUid(request);
  const offerId = normalizeString(request.data?.offerId || request.data?.listingId);
  const reviewedUserId = normalizeString(request.data?.reviewedUserId);
  const reviewerRole = request.data?.reviewerRole == null ? "requester" : assertRole(request.data?.reviewerRole, "reviewerRole");
  const reviewedRole = request.data?.reviewedRole == null ? oppositeRole(reviewerRole) : assertRole(request.data?.reviewedRole, "reviewedRole");
  const confirmationChecked = request.data?.confirmationChecked === true;
  if (!offerId || !reviewedUserId) throw new HttpsError("invalid-argument", "offerId and reviewedUserId are required");
  if (!confirmationChecked) throw new HttpsError("failed-precondition", "Experience confirmation is required");
  const rateAllowed = await canProceedRateLimited("verified_review_v2_submit", reviewerId, 20, 24 * 60 * 60 * 1000);
  if (!rateAllowed) throw new HttpsError("resource-exhausted", "Too many reviews submitted today");

  try {
    const { listingData, conversationId } = await assertReviewEligibility({ offerId, reviewerId, reviewedUserId, reviewerRole, reviewedRole });
    const criteria = readCriteria(request.data ?? {}, reviewedRole);
    const averageRating = averageCriteria(criteria);
    const moderation = analyzeReviewText(request.data?.comment ?? request.data?.publicComment);
    const privateFeedback = normalizeString(request.data?.privateFeedback).slice(0, 800) || null;
    const wouldRecommend = request.data?.wouldRecommend == null ? averageRating >= 4 : request.data?.wouldRecommend === true;
    const reviewId = reviewIdFor(offerId, reviewerId, reviewedUserId, reviewedRole);
    const reviewRef = db.collection(REVIEWS_COLLECTION).doc(reviewId);
    const listingRef = db.collection(COLLECTIONS.listings).doc(offerId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const publishAfter = admin.firestore.Timestamp.fromMillis(Date.now() + REVIEW_WINDOW_DAYS * 24 * 60 * 60 * 1000);
    const closeReason = "J’ai trouvé quelqu’un sur iliprestō";

    await db.runTransaction(async (transaction) => {
      const reviewSnap = await transaction.get(reviewRef);
      if (reviewSnap.exists) throw new HttpsError("already-exists", "A review already exists for this listing, user and role");
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
        ratingSchemaVersion: 2,
      });
      if (reviewerRole === "requester" && reviewedRole === "provider") {
        transaction.update(listingRef, requesterFoundProviderUpdate(reviewedUserId, closeReason));
      }
    });

    if (moderation.status === "pending_peer_review") await publishReciprocalReviewsIfReady(offerId, reviewerId, reviewedUserId);
    const [reviewedScore, reviewerScore] = await Promise.all([recalculateUserTrustScoreV2(reviewedUserId), recalculateUserTrustScoreV2(reviewerId)]);
    await createInAppNotification({
      notificationId: `mutual_review_${reviewId}`,
      userId: reviewedUserId,
      title: moderation.status === "pending_moderation" ? "Un avis vous concernant est en cours de vérification." : "Vous avez reçu un nouvel avis vérifié sur iliprestō.",
      message: moderation.status === "pending_peer_review" ? "Il sera publié quand l’autre avis sera reçu ou à la fin du délai de notation." : "Votre Score Confiance a été mis à jour.",
      type: "verified_review_received",
      routeName: `/profile/${encodeURIComponent(reviewedUserId)}`,
      offerId,
      data: { reviewId, status: moderation.status, ratingSchemaVersion: 2 },
    });
    logger.info("marketplace_mutual_review_submitted", { offerId, reviewId, reviewerId, reviewedUserId, reviewerRole, reviewedRole, status: moderation.status });
    return { ok: true, reviewId, status: moderation.status, averageRating, trustScore: reviewedScore.trustScore, trustScoreV2: reviewedScore.trustScoreV2, reviewerTrustScoreV2: reviewerScore.trustScoreV2 };
  } catch (error) {
    throw toHttpsError(error, "Unable to submit mutual verified review");
  }
});

export const getUserTrustScoreV2 = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const userId = normalizeString(request.data?.userId);
  if (!userId) throw new HttpsError("invalid-argument", "userId is required");
  try {
    const { trustScore, trustScoreV2 } = await recalculateUserTrustScoreV2(userId);
    const reviewsSnap = await db.collection(REVIEWS_COLLECTION).where("reviewedUserId", "==", userId).get();
    const latestReviews = reviewsSnap.docs
      .filter((doc) => isReviewPublicForScore(doc.data() ?? {}))
      .map(readReviewForScore)
      .filter((review): review is ReviewForScore => review != null)
      .sort((a, b) => (b.publishedAtMillis ?? b.createdAtMillis ?? 0) - (a.publishedAtMillis ?? a.createdAtMillis ?? 0))
      .slice(0, 6)
      .map((review) => ({ id: review.id, reviewId: review.id, offerId: review.offerId, offerTitle: review.offerTitle, averageRating: review.averageRating, criteria: review.criteria, comment: review.comment, replyText: review.replyText, reviewerRole: review.reviewerRole, reviewedRole: review.reviewedRole, roleLabel: roleLabel(review.reviewedRole), createdAtMillis: review.createdAtMillis, publishedAtMillis: review.publishedAtMillis }));
    return { ok: true, ratingsV2Enabled, ratingsPaidShowcaseEnabled: false, trustScore, trustScoreV2, latestReviews };
  } catch (error) {
    throw toHttpsError(error, "Unable to load trust score v2");
  }
});

export const reportReviewV2 = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const reporterId = requireAuthUid(request);
  const reviewId = normalizeString(request.data?.reviewId);
  const reason = normalizeString(request.data?.reason);
  const details = normalizeString(request.data?.details);
  if (!reviewId || !reason) throw new HttpsError("invalid-argument", "reviewId and reason are required");
  if (details.length > 800) throw new HttpsError("invalid-argument", "details is too long");
  try {
    const reviewRef = db.collection(REVIEWS_COLLECTION).doc(reviewId);
    const reportRef = db.collection(REVIEW_REPORTS_COLLECTION).doc(`${reviewId}__${reporterId}`);
    let reviewedUserId = "";
    await db.runTransaction(async (transaction) => {
      const [reviewSnap, reportSnap] = await Promise.all([transaction.get(reviewRef), transaction.get(reportRef)]);
      if (!reviewSnap.exists) throw new HttpsError("not-found", "Review not found");
      if (reportSnap.exists) throw new HttpsError("already-exists", "You have already reported this review");
      const data = (reviewSnap.data() ?? {}) as Record<string, unknown>;
      reviewedUserId = normalizeString(data.reviewedUserId);
      const reviewerId = normalizeString(data.reviewerId);
      if (reviewedUserId !== reporterId && reviewerId !== reporterId) throw new HttpsError("permission-denied", "Only review participants can report this review");
      transaction.set(reportRef, { reviewId, reportedBy: reporterId, reason, details: details || null, createdAt: admin.firestore.FieldValue.serverTimestamp(), status: "pending", ratingSchemaVersion: 2 });
      transaction.set(reviewRef, { reportCount: admin.firestore.FieldValue.increment(1), status: "disputed", visibleOnProfile: false, disputeCount: admin.firestore.FieldValue.increment(1), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });
    if (reviewedUserId) await recalculateUserTrustScoreV2(reviewedUserId);
    return { ok: true, statusChanged: true };
  } catch (error) {
    throw toHttpsError(error, "Unable to report review v2");
  }
});

export const replyToReviewV2 = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const userId = requireAuthUid(request);
  const reviewId = normalizeString(request.data?.reviewId);
  const replyText = normalizeString(request.data?.replyText).replace(/\s+/g, " ");
  if (!reviewId || !replyText) throw new HttpsError("invalid-argument", "reviewId and replyText are required");
  if (replyText.length > 300) throw new HttpsError("invalid-argument", "replyText is too long");
  try {
    const reviewSnap = await db.collection(REVIEWS_COLLECTION).doc(reviewId).get();
    if (!reviewSnap.exists) throw new HttpsError("not-found", "Review not found");
    const reviewData = (reviewSnap.data() ?? {}) as Record<string, unknown>;
    if (normalizeString(reviewData.reviewedUserId) !== userId) throw new HttpsError("permission-denied", "Only the reviewed user can reply to this review");
    const moderation = analyzeReviewText(replyText);
    const replyStatus = moderation.status === "pending_peer_review" ? "published" : moderation.status;
    const replyRef = db.collection(REVIEW_REPLIES_COLLECTION).doc(`${reviewId}__${userId}`);
    await replyRef.set({ reviewId, reviewedUserId: userId, replyText: moderation.comment, createdAt: admin.firestore.FieldValue.serverTimestamp(), status: replyStatus, moderationFlags: moderation.flags, ratingSchemaVersion: 2 }, { merge: true });
    await db.collection(REVIEWS_COLLECTION).doc(reviewId).set({ hasReply: true, replyText: moderation.comment, replyStatus, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true, status: replyStatus };
  } catch (error) {
    throw toHttpsError(error, "Unable to reply to review v2");
  }
});

export const publishMaturedReviewsV2 = onSchedule({ region: PROJECT_REGION, schedule: "every 24 hours" }, async () => {
  const now = admin.firestore.Timestamp.now();
  const snap = await db.collection(REVIEWS_COLLECTION).where("status", "==", "pending_peer_review").limit(200).get();
  const batch = db.batch();
  const touchedUserIds = new Set<string>();
  let count = 0;
  for (const doc of snap.docs) {
    const data = (doc.data() ?? {}) as Record<string, unknown>;
    const publishAfter = data.publishAfter;
    if (!(publishAfter instanceof admin.firestore.Timestamp) || publishAfter.toMillis() > now.toMillis()) continue;
    batch.set(doc.ref, { status: "published", visibleOnProfile: true, publishedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    touchedUserIds.add(normalizeString(data.reviewedUserId));
    count += 1;
  }
  if (count > 0) {
    await batch.commit();
    await Promise.all(Array.from(touchedUserIds).filter(Boolean).map(recalculateUserTrustScoreV2));
  }
  logger.info("marketplace_reviews_v2_matured", { count });
});
