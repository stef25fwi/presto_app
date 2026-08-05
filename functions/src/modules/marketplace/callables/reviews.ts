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
const REVIEW_REPORTS_COLLECTION = "review_reports";
const REVIEW_REPLIES_COLLECTION = "review_replies";
const JOB_DONE_OVERLAY_HOURS = 10;
const DISPUTE_REPORT_THRESHOLD = 2;

export const ratingsPaidShowcaseEnabled = false;

type ReviewStatus = "published" | "pending_moderation" | "rejected" | "disputed" | "hidden";

interface ModerationFlags {
  containsPersonalData: boolean;
  containsInsult: boolean;
  containsThreat: boolean;
  containsSuspiciousContent: boolean;
}

interface ResponderCandidate {
  userId: string;
  responseAtMillis: number | null;
  conversationId: string;
  participantName: string;
}

interface PublishedReviewForScore {
  id: string;
  offerTitle: string;
  communicationRating: number;
  punctualityRating: number;
  qualityRating: number;
  averageRating: number;
  comment: string | null;
  createdAtMillis: number | null;
  publishedAtMillis: number | null;
}

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

function readTimestampMillis(value: unknown): number | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}

function reviewIdFor(offerId: string, reviewerId: string, reviewedUserId: string): string {
  return [offerId, reviewerId, reviewedUserId]
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

export function calculateReviewAverage(
  communicationRating: number,
  punctualityRating: number,
  qualityRating: number,
): number {
  return Number(((communicationRating + punctualityRating + qualityRating) / 3).toFixed(3));
}

export function analyzeReviewText(rawComment: unknown): { comment: string | null; flags: ModerationFlags; status: ReviewStatus } {
  const comment = normalizeString(rawComment).replace(/\s+/g, " ");
  if (comment.length > 500) {
    throw new HttpsError("invalid-argument", "Comment is too long");
  }

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

  const needsModeration = Object.values(flags).some(Boolean);
  return {
    comment: comment || null,
    flags,
    status: needsModeration ? "pending_moderation" : "published",
  };
}

function isFoundOnIliPrestoReason(reason: unknown): boolean {
  const normalized = normalizeSearchText(normalizeString(reason));
  return normalized === "found_on_ilipresto"
    || (normalized.includes("trouve quelqu") && normalized.includes("ilipresto"));
}

function readParticipantNames(data: Record<string, unknown>): Record<string, string> {
  const raw = (data.participantNames || data.participant_names) as Record<string, unknown> | undefined;
  if (!raw || typeof raw !== "object") return {};
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(raw)) {
    const normalizedKey = normalizeString(key);
    const normalizedValue = normalizeString(value);
    if (normalizedKey && normalizedValue) result[normalizedKey] = normalizedValue;
  }
  return result;
}

async function loadResponderCandidates(offerId: string, ownerId: string): Promise<ResponderCandidate[]> {
  const snapshots = await Promise.all(
    ["offerId", "listingId", "offer_id", "listing_id"].map((field) =>
      db.collection(COLLECTIONS.conversations).where(field, "==", offerId).limit(100).get(),
    ),
  );

  const byUserId = new Map<string, ResponderCandidate>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      const data = (doc.data() ?? {}) as Record<string, unknown>;
      const participants = readConversationParticipants(data, { conversationId: doc.id });
      if (!participants.includes(ownerId)) continue;

      const names = readParticipantNames(data);
      const responseAtMillis = readTimestampMillis(data.createdAt)
        ?? readTimestampMillis(data.created_at)
        ?? readTimestampMillis(data.lastMessageAt)
        ?? readTimestampMillis(data.last_message_at)
        ?? readTimestampMillis(data.updatedAt)
        ?? null;

      for (const participantId of participants) {
        if (!participantId || participantId === ownerId) continue;
        const existing = byUserId.get(participantId);
        if (existing && (existing.responseAtMillis ?? Number.MAX_SAFE_INTEGER) <= (responseAtMillis ?? Number.MAX_SAFE_INTEGER)) {
          continue;
        }
        byUserId.set(participantId, {
          userId: participantId,
          responseAtMillis,
          conversationId: doc.id,
          participantName: names[participantId] || "",
        });
      }
    }
  }

  return Array.from(byUserId.values());
}

async function assertListingOwnedBy(offerId: string, ownerId: string): Promise<Record<string, unknown>> {
  const listingSnap = await db.collection(COLLECTIONS.listings).doc(offerId).get();
  if (!listingSnap.exists) {
    throw new HttpsError("not-found", "Listing not found");
  }
  const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
  if (readListingOwnerId(listingData) !== ownerId) {
    throw new HttpsError("permission-denied", "You do not own this listing");
  }
  return listingData;
}

function buildTrustBadges(stats: {
  publishedReviewsCount: number;
  average: number;
  communicationAverage: number;
  punctualityAverage: number;
  qualityAverage: number;
}): string[] {
  const badges: string[] = [];
  if (stats.publishedReviewsCount === 0) badges.push("new_profile");
  if (stats.publishedReviewsCount === 1) badges.push("first_review_received");
  if (stats.publishedReviewsCount >= 1) badges.push("verified_reviews_ilipresto");
  if (stats.average >= 4.3 && stats.publishedReviewsCount >= 3) badges.push("well_rated_profile");
  if (stats.communicationAverage >= 4.5 && stats.publishedReviewsCount >= 3) badges.push("top_communication");
  if (stats.punctualityAverage >= 4.5 && stats.publishedReviewsCount >= 3) badges.push("punctual");
  if (stats.qualityAverage >= 4.5 && stats.publishedReviewsCount >= 3) badges.push("recommended_quality");
  return badges;
}

function summarizePublishedReviews(reviews: PublishedReviewForScore[]) {
  const count = reviews.length;
  const sum = (selector: (review: PublishedReviewForScore) => number) =>
    reviews.reduce((total, review) => total + selector(review), 0);
  const average = (value: number) => count === 0 ? 0 : Number((value / count).toFixed(3));
  const firstMillis = reviews
    .map((review) => review.publishedAtMillis ?? review.createdAtMillis)
    .filter((value): value is number => typeof value === "number")
    .sort((a, b) => a - b)[0] ?? null;
  const lastMillis = reviews
    .map((review) => review.publishedAtMillis ?? review.createdAtMillis)
    .filter((value): value is number => typeof value === "number")
    .sort((a, b) => b - a)[0] ?? null;

  const stats = {
    average: average(sum((review) => review.averageRating)),
    communicationAverage: average(sum((review) => review.communicationRating)),
    punctualityAverage: average(sum((review) => review.punctualityRating)),
    qualityAverage: average(sum((review) => review.qualityRating)),
    reviewsCount: count,
    publishedReviewsCount: count,
    firstReviewAt: firstMillis == null ? null : admin.firestore.Timestamp.fromMillis(firstMillis),
    lastReviewAt: lastMillis == null ? null : admin.firestore.Timestamp.fromMillis(lastMillis),
    freeFullDisplayUntil: firstMillis == null
      ? null
      : admin.firestore.Timestamp.fromMillis(firstMillis + 183 * 24 * 60 * 60 * 1000),
  };
  return {
    ...stats,
    paidShowcaseActive: false,
    badges: buildTrustBadges(stats),
  };
}

function serializeTrustScore(score: Record<string, unknown>): Record<string, unknown> {
  const badges = Array.isArray(score.badges)
    ? score.badges.map((value) => normalizeString(value)).filter(Boolean)
    : [];
  return {
    average: Number(score.average || 0),
    communicationAverage: Number(score.communicationAverage || 0),
    punctualityAverage: Number(score.punctualityAverage || 0),
    qualityAverage: Number(score.qualityAverage || 0),
    reviewsCount: Number(score.reviewsCount || 0),
    publishedReviewsCount: Number(score.publishedReviewsCount || 0),
    pendingReviewsCount: Number(score.pendingReviewsCount || 0),
    firstReviewAtMillis: readTimestampMillis(score.firstReviewAt),
    lastReviewAtMillis: readTimestampMillis(score.lastReviewAt),
    freeFullDisplayUntilMillis: readTimestampMillis(score.freeFullDisplayUntil),
    paidShowcaseActive: score.paidShowcaseActive === true,
    badges,
  };
}

export async function recalculateUserTrustScore(userId: string): Promise<Record<string, unknown>> {
  const snap = await db.collection(REVIEWS_COLLECTION).where("reviewedUserId", "==", userId).get();
  const publishedReviews: PublishedReviewForScore[] = [];
  let pendingReviewsCount = 0;

  for (const doc of snap.docs) {
    const data = (doc.data() ?? {}) as Record<string, unknown>;
    const status = normalizeString(data.status);
    if (status === "pending_moderation") pendingReviewsCount += 1;
    if (status !== "published" || data.visibleOnProfile === false || data.isVerified !== true) continue;
    publishedReviews.push({
      id: doc.id,
      offerTitle: normalizeString(data.offerTitle) || "Annonce iliprestō",
      communicationRating: Number(data.communicationRating || 0),
      punctualityRating: Number(data.punctualityRating || 0),
      qualityRating: Number(data.qualityRating || 0),
      averageRating: Number(data.averageRating || 0),
      comment: normalizeString(data.comment) || null,
      createdAtMillis: readTimestampMillis(data.createdAt),
      publishedAtMillis: readTimestampMillis(data.publishedAt),
    });
  }

  const score = {
    ...summarizePublishedReviews(publishedReviews),
    reviewsCount: snap.size,
    pendingReviewsCount,
  };

  await db.collection(COLLECTIONS.users).doc(userId).set({
    trustScore: score,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return score;
}

export const getEligibleRespondersForReview = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const ownerId = requireAuthUid(request);
  const offerId = normalizeString(request.data?.offerId || request.data?.listingId);
  if (!offerId) {
    throw new HttpsError("invalid-argument", "offerId is required");
  }

  try {
    await assertListingOwnedBy(offerId, ownerId);
    const candidates = await loadResponderCandidates(offerId, ownerId);
    const responders = [];

    for (const candidate of candidates) {
      const reviewSnap = await db.collection(REVIEWS_COLLECTION)
        .doc(reviewIdFor(offerId, ownerId, candidate.userId))
        .get();
      if (reviewSnap.exists) continue;

      const userSnap = await db.collection(COLLECTIONS.users).doc(candidate.userId).get();
      const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
      responders.push({
        userId: candidate.userId,
        pseudo: readDisplayName(userData, candidate.participantName || "Utilisateur iliprestō"),
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
    throw toHttpsError(error, "Unable to list eligible responders");
  }
});

export const submitVerifiedReview = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const reviewerId = requireAuthUid(request);
  const offerId = normalizeString(request.data?.offerId || request.data?.listingId);
  const reviewedUserId = normalizeString(request.data?.reviewedUserId);
  const confirmationChecked = request.data?.confirmationChecked === true;

  if (!offerId || !reviewedUserId) {
    throw new HttpsError("invalid-argument", "offerId and reviewedUserId are required");
  }
  if (reviewedUserId === reviewerId) {
    throw new HttpsError("failed-precondition", "You cannot review yourself");
  }
  if (!confirmationChecked) {
    throw new HttpsError("failed-precondition", "Experience confirmation is required");
  }

  const rateAllowed = await canProceedRateLimited("verified_review_submit", reviewerId, 20, 24 * 60 * 60 * 1000);
  if (!rateAllowed) {
    throw new HttpsError("resource-exhausted", "Too many reviews submitted today");
  }

  try {
    const listingData = await assertListingOwnedBy(offerId, reviewerId);
    const candidates = await loadResponderCandidates(offerId, reviewerId);
    const candidate = candidates.find((entry) => entry.userId === reviewedUserId);
    if (!candidate) {
      throw new HttpsError("permission-denied", "This user did not respond to this listing");
    }

    const communicationRating = assertRating(request.data?.communicationRating, "communicationRating");
    const punctualityRating = assertRating(request.data?.punctualityRating, "punctualityRating");
    const qualityRating = assertRating(request.data?.qualityRating, "qualityRating");
    const averageRating = calculateReviewAverage(communicationRating, punctualityRating, qualityRating);
    const moderation = analyzeReviewText(request.data?.comment);
    const reviewId = reviewIdFor(offerId, reviewerId, reviewedUserId);
    const reviewRef = db.collection(REVIEWS_COLLECTION).doc(reviewId);
    const listingRef = db.collection(COLLECTIONS.listings).doc(offerId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    const visibleUntil = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + JOB_DONE_OVERLAY_HOURS * 60 * 60 * 1000),
    );
    const closeReason = "J’ai trouvé quelqu’un sur iliprestō";
    const existingReason = normalizeString(listingData.closedReason || listingData.deletedReason || listingData.archiveReason);
    if (existingReason && !isFoundOnIliPrestoReason(existingReason)) {
      throw new HttpsError("failed-precondition", "Listing was not closed as found on iliprestō");
    }

    await db.runTransaction(async (transaction) => {
      const reviewSnap = await transaction.get(reviewRef);
      if (reviewSnap.exists) {
        throw new HttpsError("already-exists", "A review already exists for this listing and user");
      }

      transaction.set(reviewRef, {
        reviewId,
        offerId,
        offerTitle: normalizeString(listingData.title || listingData.titre) || "Annonce iliprestō",
        offerOwnerId: reviewerId,
        reviewerId,
        reviewedUserId,
        communicationRating,
        punctualityRating,
        qualityRating,
        averageRating,
        comment: moderation.comment,
        status: moderation.status,
        isVerified: true,
        verificationType: "offer_response_selected",
        confirmationChecked: true,
        responderConversationId: candidate.conversationId,
        responderResponseAtMillis: candidate.responseAtMillis,
        createdAt: now,
        updatedAt: null,
        publishedAt: moderation.status === "published" ? now : null,
        moderationFlags: moderation.flags,
        reportCount: 0,
        disputeCount: 0,
        visibleOnProfile: moderation.status === "published",
      });

      transaction.update(listingRef, {
        status: "active",
        visibility: "public",
        isActive: true,
        isPublished: true,
        selectedUserId: reviewedUserId,
        closedReason: closeReason,
        deletedReason: closeReason,
        archiveReason: closeReason,
        closedAt: now,
        deletedAt: now,
        reviewRequested: true,
        reviewSubmitted: true,
        jobDoneOverlayVisible: true,
        jobDoneOverlayVisibleUntil: visibleUntil,
        removeFromBrowseAt: visibleUntil,
        updatedAt: now,
      });
    });

    const trustScore = await recalculateUserTrustScore(reviewedUserId);
    await createInAppNotification({
      notificationId: `verified_review_${reviewId}`,
      userId: reviewedUserId,
      title: moderation.status === "published"
        ? "Vous avez reçu un nouvel avis vérifié sur iliprestō."
        : "Un avis vous concernant est en cours de vérification.",
      message: moderation.status === "published"
        ? "Votre Score Confiance a été mis à jour."
        : "Un avis vous concernant est en cours de vérification.",
      type: "verified_review_received",
      routeName: `/profile/${encodeURIComponent(reviewedUserId)}`,
      offerId,
      data: { reviewId, status: moderation.status },
    });

    logger.info("marketplace_verified_review_submitted", {
      offerId,
      reviewId,
      reviewerId,
      reviewedUserId,
      status: moderation.status,
    });

    return { ok: true, reviewId, status: moderation.status, averageRating, trustScore: serializeTrustScore(trustScore) };
  } catch (error) {
    throw toHttpsError(error, "Unable to submit verified review");
  }
});

export const getUserTrustScore = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const userId = normalizeString(request.data?.userId);
  if (!userId) {
    throw new HttpsError("invalid-argument", "userId is required");
  }

  try {
    const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
    let trustScore = (userSnap.data()?.trustScore ?? null) as Record<string, unknown> | null;
    const reviewsSnap = await db.collection(REVIEWS_COLLECTION).where("reviewedUserId", "==", userId).get();
    const latestReviews: PublishedReviewForScore[] = [];

    for (const doc of reviewsSnap.docs) {
      const data = (doc.data() ?? {}) as Record<string, unknown>;
      if (normalizeString(data.status) !== "published" || data.visibleOnProfile === false || data.isVerified !== true) {
        continue;
      }
      latestReviews.push({
        id: doc.id,
        offerTitle: normalizeString(data.offerTitle) || "Annonce iliprestō",
        communicationRating: Number(data.communicationRating || 0),
        punctualityRating: Number(data.punctualityRating || 0),
        qualityRating: Number(data.qualityRating || 0),
        averageRating: Number(data.averageRating || 0),
        comment: normalizeString(data.comment) || null,
        createdAtMillis: readTimestampMillis(data.createdAt),
        publishedAtMillis: readTimestampMillis(data.publishedAt),
      });
    }

    latestReviews.sort((a, b) => (b.publishedAtMillis ?? b.createdAtMillis ?? 0) - (a.publishedAtMillis ?? a.createdAtMillis ?? 0));
    if (!trustScore) {
      trustScore = await recalculateUserTrustScore(userId);
    }

    return {
      ok: true,
      ratingsPaidShowcaseEnabled,
      trustScore: serializeTrustScore(trustScore),
      latestReviews: latestReviews.slice(0, 3),
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to load trust score");
  }
});

export const reportReview = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const reporterId = requireAuthUid(request);
  const reviewId = normalizeString(request.data?.reviewId);
  const reason = normalizeString(request.data?.reason);
  const details = normalizeString(request.data?.details);
  if (!reviewId || !reason) {
    throw new HttpsError("invalid-argument", "reviewId and reason are required");
  }
  if (details.length > 800) {
    throw new HttpsError("invalid-argument", "details is too long");
  }

  try {
    const reviewRef = db.collection(REVIEWS_COLLECTION).doc(reviewId);
    const reportRef = db.collection(REVIEW_REPORTS_COLLECTION).doc(`${reviewId}__${reporterId}`);
    let reviewedUserId = "";
    let statusChanged = false;

    await db.runTransaction(async (transaction) => {
      const [reviewSnap, reportSnap] = await Promise.all([
        transaction.get(reviewRef),
        transaction.get(reportRef),
      ]);
      if (!reviewSnap.exists) {
        throw new HttpsError("not-found", "Review not found");
      }
      if (reportSnap.exists) {
        throw new HttpsError("already-exists", "You have already reported this review");
      }
      const data = (reviewSnap.data() ?? {}) as Record<string, unknown>;
      reviewedUserId = normalizeString(data.reviewedUserId);
      if (reviewedUserId !== reporterId) {
        throw new HttpsError("permission-denied", "Only the reviewed user can report this review");
      }
      const newReportCount = Number(data.reportCount || 0) + 1;
      transaction.set(reportRef, {
        reviewId,
        reportedBy: reporterId,
        reason,
        details: details || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "pending",
      });
      transaction.set(reviewRef, {
        reportCount: newReportCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(newReportCount >= DISPUTE_REPORT_THRESHOLD ? {
          status: "disputed",
          visibleOnProfile: false,
          disputeCount: admin.firestore.FieldValue.increment(1),
        } : {}),
      }, { merge: true });
      statusChanged = newReportCount >= DISPUTE_REPORT_THRESHOLD;
    });

    if (statusChanged && reviewedUserId) {
      await recalculateUserTrustScore(reviewedUserId);
    }

    return { ok: true, statusChanged };
  } catch (error) {
    throw toHttpsError(error, "Unable to report review");
  }
});

export const replyToReview = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const userId = requireAuthUid(request);
  const reviewId = normalizeString(request.data?.reviewId);
  const replyText = normalizeString(request.data?.replyText).replace(/\s+/g, " ");
  if (!reviewId || !replyText) {
    throw new HttpsError("invalid-argument", "reviewId and replyText are required");
  }
  if (replyText.length > 300) {
    throw new HttpsError("invalid-argument", "replyText is too long");
  }

  try {
    const reviewSnap = await db.collection(REVIEWS_COLLECTION).doc(reviewId).get();
    if (!reviewSnap.exists) {
      throw new HttpsError("not-found", "Review not found");
    }
    const reviewData = (reviewSnap.data() ?? {}) as Record<string, unknown>;
    if (normalizeString(reviewData.reviewedUserId) !== userId) {
      throw new HttpsError("permission-denied", "Only the reviewed user can reply to this review");
    }

    const moderation = analyzeReviewText(replyText);
    const replyRef = db.collection(REVIEW_REPLIES_COLLECTION).doc(`${reviewId}__${userId}`);
    await replyRef.set({
      reviewId,
      reviewedUserId: userId,
      replyText: moderation.comment,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: moderation.status,
      moderationFlags: moderation.flags,
    }, { merge: true });

    await db.collection(REVIEWS_COLLECTION).doc(reviewId).set({
      hasReply: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, status: moderation.status };
  } catch (error) {
    throw toHttpsError(error, "Unable to reply to review");
  }
});