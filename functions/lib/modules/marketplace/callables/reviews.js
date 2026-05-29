"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.replyToReview = exports.reportReview = exports.getUserTrustScore = exports.submitVerifiedReview = exports.getEligibleRespondersForReview = exports.ratingsPaidShowcaseEnabled = void 0;
exports.calculateReviewAverage = calculateReviewAverage;
exports.analyzeReviewText = analyzeReviewText;
exports.recalculateUserTrustScore = recalculateUserTrustScore;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const rate_limit_1 = require("../../../core/rate_limit");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const participants_1 = require("../../messaging/participants");
const push_1 = require("../../notifications/push");
const errors_1 = require("../services/errors");
const REVIEWS_COLLECTION = "reviews";
const REVIEW_REPORTS_COLLECTION = "review_reports";
const REVIEW_REPLIES_COLLECTION = "review_replies";
const JOB_DONE_OVERLAY_HOURS = 10;
const DISPUTE_REPORT_THRESHOLD = 2;
exports.ratingsPaidShowcaseEnabled = false;
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
function normalizeString(value) {
    return String(value ?? "").trim();
}
function normalizeSearchText(value) {
    return value
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/\s+/g, " ")
        .trim();
}
function readListingOwnerId(data) {
    return normalizeString(data.ownerId) || normalizeString(data.userId) || normalizeString(data.uid);
}
function readDisplayName(data, fallback = "Utilisateur iliprestō") {
    for (const field of ["pseudo", "displayName", "display_name", "username", "name"]) {
        const value = normalizeString(data[field]);
        if (value)
            return value;
    }
    return fallback;
}
function readCity(data) {
    for (const field of ["city", "ville", "commune", "locality", "cityLabel"]) {
        const value = normalizeString(data[field]);
        if (value)
            return value;
    }
    return "";
}
function readPhotoUrl(data) {
    for (const field of ["photoUrl", "photoURL", "avatarUrl", "avatar", "profilePhotoUrl"]) {
        const value = normalizeString(data[field]);
        if (value)
            return value;
    }
    return null;
}
function readTimestampMillis(value) {
    if (!value)
        return null;
    if (value instanceof firebase_admin_1.default.firestore.Timestamp)
        return value.toMillis();
    if (value instanceof Date)
        return value.getTime();
    if (typeof value === "number" && Number.isFinite(value))
        return value;
    return null;
}
function reviewIdFor(offerId, reviewerId, reviewedUserId) {
    return [offerId, reviewerId, reviewedUserId]
        .map((part) => encodeURIComponent(part.replaceAll("/", "_")))
        .join("__");
}
function assertRating(value, fieldName) {
    const rating = Number(value);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
        throw new https_1.HttpsError("invalid-argument", `${fieldName} must be an integer between 1 and 5`);
    }
    return rating;
}
function calculateReviewAverage(communicationRating, punctualityRating, qualityRating) {
    return Number(((communicationRating + punctualityRating + qualityRating) / 3).toFixed(3));
}
function analyzeReviewText(rawComment) {
    const comment = normalizeString(rawComment).replace(/\s+/g, " ");
    if (comment.length > 500) {
        throw new https_1.HttpsError("invalid-argument", "Comment is too long");
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
function isFoundOnIliPrestoReason(reason) {
    const normalized = normalizeSearchText(normalizeString(reason));
    return normalized === "found_on_ilipresto"
        || (normalized.includes("trouve quelqu") && normalized.includes("ilipresto"));
}
function readParticipantNames(data) {
    const raw = (data.participantNames || data.participant_names);
    if (!raw || typeof raw !== "object")
        return {};
    const result = {};
    for (const [key, value] of Object.entries(raw)) {
        const normalizedKey = normalizeString(key);
        const normalizedValue = normalizeString(value);
        if (normalizedKey && normalizedValue)
            result[normalizedKey] = normalizedValue;
    }
    return result;
}
async function loadResponderCandidates(offerId, ownerId) {
    const snapshots = await Promise.all(["offerId", "listingId", "offer_id", "listing_id"].map((field) => firestore_1.db.collection(constants_1.COLLECTIONS.conversations).where(field, "==", offerId).limit(100).get()));
    const byUserId = new Map();
    for (const snapshot of snapshots) {
        for (const doc of snapshot.docs) {
            const data = (doc.data() ?? {});
            const participants = (0, participants_1.readConversationParticipants)(data, { conversationId: doc.id });
            if (!participants.includes(ownerId))
                continue;
            const names = readParticipantNames(data);
            const responseAtMillis = readTimestampMillis(data.createdAt)
                ?? readTimestampMillis(data.created_at)
                ?? readTimestampMillis(data.lastMessageAt)
                ?? readTimestampMillis(data.last_message_at)
                ?? readTimestampMillis(data.updatedAt)
                ?? null;
            for (const participantId of participants) {
                if (!participantId || participantId === ownerId)
                    continue;
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
async function assertListingOwnedBy(offerId, ownerId) {
    const listingSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(offerId).get();
    if (!listingSnap.exists) {
        throw new https_1.HttpsError("not-found", "Listing not found");
    }
    const listingData = (listingSnap.data() ?? {});
    if (readListingOwnerId(listingData) !== ownerId) {
        throw new https_1.HttpsError("permission-denied", "You do not own this listing");
    }
    return listingData;
}
function buildTrustBadges(stats) {
    const badges = [];
    if (stats.publishedReviewsCount === 0)
        badges.push("new_profile");
    if (stats.publishedReviewsCount === 1)
        badges.push("first_review_received");
    if (stats.publishedReviewsCount >= 1)
        badges.push("verified_reviews_ilipresto");
    if (stats.average >= 4.3 && stats.publishedReviewsCount >= 3)
        badges.push("well_rated_profile");
    if (stats.communicationAverage >= 4.5 && stats.publishedReviewsCount >= 3)
        badges.push("top_communication");
    if (stats.punctualityAverage >= 4.5 && stats.publishedReviewsCount >= 3)
        badges.push("punctual");
    if (stats.qualityAverage >= 4.5 && stats.publishedReviewsCount >= 3)
        badges.push("recommended_quality");
    return badges;
}
function summarizePublishedReviews(reviews) {
    const count = reviews.length;
    const sum = (selector) => reviews.reduce((total, review) => total + selector(review), 0);
    const average = (value) => count === 0 ? 0 : Number((value / count).toFixed(3));
    const firstMillis = reviews
        .map((review) => review.publishedAtMillis ?? review.createdAtMillis)
        .filter((value) => typeof value === "number")
        .sort((a, b) => a - b)[0] ?? null;
    const lastMillis = reviews
        .map((review) => review.publishedAtMillis ?? review.createdAtMillis)
        .filter((value) => typeof value === "number")
        .sort((a, b) => b - a)[0] ?? null;
    const stats = {
        average: average(sum((review) => review.averageRating)),
        communicationAverage: average(sum((review) => review.communicationRating)),
        punctualityAverage: average(sum((review) => review.punctualityRating)),
        qualityAverage: average(sum((review) => review.qualityRating)),
        reviewsCount: count,
        publishedReviewsCount: count,
        firstReviewAt: firstMillis == null ? null : firebase_admin_1.default.firestore.Timestamp.fromMillis(firstMillis),
        lastReviewAt: lastMillis == null ? null : firebase_admin_1.default.firestore.Timestamp.fromMillis(lastMillis),
        freeFullDisplayUntil: firstMillis == null
            ? null
            : firebase_admin_1.default.firestore.Timestamp.fromMillis(firstMillis + 183 * 24 * 60 * 60 * 1000),
    };
    return {
        ...stats,
        paidShowcaseActive: false,
        badges: buildTrustBadges(stats),
    };
}
function serializeTrustScore(score) {
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
async function recalculateUserTrustScore(userId) {
    const snap = await firestore_1.db.collection(REVIEWS_COLLECTION).where("reviewedUserId", "==", userId).get();
    const publishedReviews = [];
    let pendingReviewsCount = 0;
    for (const doc of snap.docs) {
        const data = (doc.data() ?? {});
        const status = normalizeString(data.status);
        if (status === "pending_moderation")
            pendingReviewsCount += 1;
        if (status !== "published" || data.visibleOnProfile === false || data.isVerified !== true)
            continue;
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
    await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).set({
        trustScore: score,
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return score;
}
exports.getEligibleRespondersForReview = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const ownerId = requireAuthUid(request);
    const offerId = normalizeString(request.data?.offerId || request.data?.listingId);
    if (!offerId) {
        throw new https_1.HttpsError("invalid-argument", "offerId is required");
    }
    try {
        await assertListingOwnedBy(offerId, ownerId);
        const candidates = await loadResponderCandidates(offerId, ownerId);
        const responders = [];
        for (const candidate of candidates) {
            const reviewSnap = await firestore_1.db.collection(REVIEWS_COLLECTION)
                .doc(reviewIdFor(offerId, ownerId, candidate.userId))
                .get();
            if (reviewSnap.exists)
                continue;
            const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(candidate.userId).get();
            const userData = (userSnap.data() ?? {});
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
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to list eligible responders");
    }
});
exports.submitVerifiedReview = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const reviewerId = requireAuthUid(request);
    const offerId = normalizeString(request.data?.offerId || request.data?.listingId);
    const reviewedUserId = normalizeString(request.data?.reviewedUserId);
    const confirmationChecked = request.data?.confirmationChecked === true;
    if (!offerId || !reviewedUserId) {
        throw new https_1.HttpsError("invalid-argument", "offerId and reviewedUserId are required");
    }
    if (reviewedUserId === reviewerId) {
        throw new https_1.HttpsError("failed-precondition", "You cannot review yourself");
    }
    if (!confirmationChecked) {
        throw new https_1.HttpsError("failed-precondition", "Experience confirmation is required");
    }
    const rateAllowed = await (0, rate_limit_1.canProceedRateLimited)("verified_review_submit", reviewerId, 20, 24 * 60 * 60 * 1000);
    if (!rateAllowed) {
        throw new https_1.HttpsError("resource-exhausted", "Too many reviews submitted today");
    }
    try {
        const listingData = await assertListingOwnedBy(offerId, reviewerId);
        const candidates = await loadResponderCandidates(offerId, reviewerId);
        const candidate = candidates.find((entry) => entry.userId === reviewedUserId);
        if (!candidate) {
            throw new https_1.HttpsError("permission-denied", "This user did not respond to this listing");
        }
        const communicationRating = assertRating(request.data?.communicationRating, "communicationRating");
        const punctualityRating = assertRating(request.data?.punctualityRating, "punctualityRating");
        const qualityRating = assertRating(request.data?.qualityRating, "qualityRating");
        const averageRating = calculateReviewAverage(communicationRating, punctualityRating, qualityRating);
        const moderation = analyzeReviewText(request.data?.comment);
        const reviewId = reviewIdFor(offerId, reviewerId, reviewedUserId);
        const reviewRef = firestore_1.db.collection(REVIEWS_COLLECTION).doc(reviewId);
        const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(offerId);
        const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        const visibleUntil = firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() + JOB_DONE_OVERLAY_HOURS * 60 * 60 * 1000));
        const closeReason = "J’ai trouvé quelqu’un sur iliprestō";
        const existingReason = normalizeString(listingData.closedReason || listingData.deletedReason || listingData.archiveReason);
        if (existingReason && !isFoundOnIliPrestoReason(existingReason)) {
            throw new https_1.HttpsError("failed-precondition", "Listing was not closed as found on iliprestō");
        }
        await firestore_1.db.runTransaction(async (transaction) => {
            const reviewSnap = await transaction.get(reviewRef);
            if (reviewSnap.exists) {
                throw new https_1.HttpsError("already-exists", "A review already exists for this listing and user");
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
        await (0, push_1.createInAppNotification)({
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
        logger_1.logger.info("marketplace_verified_review_submitted", {
            offerId,
            reviewId,
            reviewerId,
            reviewedUserId,
            status: moderation.status,
        });
        return { ok: true, reviewId, status: moderation.status, averageRating, trustScore: serializeTrustScore(trustScore) };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to submit verified review");
    }
});
exports.getUserTrustScore = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const userId = normalizeString(request.data?.userId);
    if (!userId) {
        throw new https_1.HttpsError("invalid-argument", "userId is required");
    }
    try {
        const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
        let trustScore = (userSnap.data()?.trustScore ?? null);
        const reviewsSnap = await firestore_1.db.collection(REVIEWS_COLLECTION).where("reviewedUserId", "==", userId).get();
        const latestReviews = [];
        for (const doc of reviewsSnap.docs) {
            const data = (doc.data() ?? {});
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
            ratingsPaidShowcaseEnabled: exports.ratingsPaidShowcaseEnabled,
            trustScore: serializeTrustScore(trustScore),
            latestReviews: latestReviews.slice(0, 3),
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to load trust score");
    }
});
exports.reportReview = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const reporterId = requireAuthUid(request);
    const reviewId = normalizeString(request.data?.reviewId);
    const reason = normalizeString(request.data?.reason);
    const details = normalizeString(request.data?.details);
    if (!reviewId || !reason) {
        throw new https_1.HttpsError("invalid-argument", "reviewId and reason are required");
    }
    if (details.length > 800) {
        throw new https_1.HttpsError("invalid-argument", "details is too long");
    }
    try {
        const reviewRef = firestore_1.db.collection(REVIEWS_COLLECTION).doc(reviewId);
        const reportRef = firestore_1.db.collection(REVIEW_REPORTS_COLLECTION).doc(`${reviewId}__${reporterId}`);
        let reviewedUserId = "";
        let statusChanged = false;
        await firestore_1.db.runTransaction(async (transaction) => {
            const [reviewSnap, reportSnap] = await Promise.all([
                transaction.get(reviewRef),
                transaction.get(reportRef),
            ]);
            if (!reviewSnap.exists) {
                throw new https_1.HttpsError("not-found", "Review not found");
            }
            if (reportSnap.exists) {
                throw new https_1.HttpsError("already-exists", "You have already reported this review");
            }
            const data = (reviewSnap.data() ?? {});
            reviewedUserId = normalizeString(data.reviewedUserId);
            if (reviewedUserId !== reporterId) {
                throw new https_1.HttpsError("permission-denied", "Only the reviewed user can report this review");
            }
            const newReportCount = Number(data.reportCount || 0) + 1;
            transaction.set(reportRef, {
                reviewId,
                reportedBy: reporterId,
                reason,
                details: details || null,
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                status: "pending",
            });
            transaction.set(reviewRef, {
                reportCount: newReportCount,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                ...(newReportCount >= DISPUTE_REPORT_THRESHOLD ? {
                    status: "disputed",
                    visibleOnProfile: false,
                    disputeCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
                } : {}),
            }, { merge: true });
            statusChanged = newReportCount >= DISPUTE_REPORT_THRESHOLD;
        });
        if (statusChanged && reviewedUserId) {
            await recalculateUserTrustScore(reviewedUserId);
        }
        return { ok: true, statusChanged };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to report review");
    }
});
exports.replyToReview = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const userId = requireAuthUid(request);
    const reviewId = normalizeString(request.data?.reviewId);
    const replyText = normalizeString(request.data?.replyText).replace(/\s+/g, " ");
    if (!reviewId || !replyText) {
        throw new https_1.HttpsError("invalid-argument", "reviewId and replyText are required");
    }
    if (replyText.length > 300) {
        throw new https_1.HttpsError("invalid-argument", "replyText is too long");
    }
    try {
        const reviewSnap = await firestore_1.db.collection(REVIEWS_COLLECTION).doc(reviewId).get();
        if (!reviewSnap.exists) {
            throw new https_1.HttpsError("not-found", "Review not found");
        }
        const reviewData = (reviewSnap.data() ?? {});
        if (normalizeString(reviewData.reviewedUserId) !== userId) {
            throw new https_1.HttpsError("permission-denied", "Only the reviewed user can reply to this review");
        }
        const moderation = analyzeReviewText(replyText);
        const replyRef = firestore_1.db.collection(REVIEW_REPLIES_COLLECTION).doc(`${reviewId}__${userId}`);
        await replyRef.set({
            reviewId,
            reviewedUserId: userId,
            replyText: moderation.comment,
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            status: moderation.status,
            moderationFlags: moderation.flags,
        }, { merge: true });
        await firestore_1.db.collection(REVIEWS_COLLECTION).doc(reviewId).set({
            hasReply: true,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return { ok: true, status: moderation.status };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to reply to review");
    }
});
//# sourceMappingURL=reviews.js.map