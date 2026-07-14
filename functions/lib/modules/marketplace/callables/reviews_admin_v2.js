"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminModerateReviewV2 = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const push_1 = require("../../notifications/push");
const errors_1 = require("../services/errors");
const roles_1 = require("../services/roles");
const REVIEWS_COLLECTION = "reviews";
const REVIEW_MODERATION_ACTIONS_COLLECTION = "review_moderation_actions";
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
function assertDecision(value) {
    const decision = normalizeString(value);
    if (decision === "publish" ||
        decision === "hide" ||
        decision === "reject" ||
        decision === "request_correction") {
        return decision;
    }
    throw new https_1.HttpsError("invalid-argument", "decision must be publish, hide, reject or request_correction");
}
function patchForDecision(decision, note) {
    const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
    switch (decision) {
        case "publish":
            return {
                status: "published",
                visibleOnProfile: true,
                publishedAt: now,
                moderationStatus: "approved",
                adminModerationNote: note || null,
                updatedAt: now,
            };
        case "hide":
            return {
                status: "hidden",
                visibleOnProfile: false,
                moderationStatus: "hidden",
                adminModerationNote: note || null,
                updatedAt: now,
            };
        case "reject":
            return {
                status: "rejected",
                visibleOnProfile: false,
                moderationStatus: "rejected",
                adminModerationNote: note || null,
                updatedAt: now,
            };
        case "request_correction":
            return {
                status: "pending_moderation",
                visibleOnProfile: false,
                moderationStatus: "correction_requested",
                correctionRequested: true,
                correctionMessage: note || "Merci de modifier cet avis avant publication.",
                adminModerationNote: note || null,
                updatedAt: now,
            };
    }
}
function userNotificationForDecision(decision) {
    switch (decision) {
        case "publish":
            return {
                title: "Avis publié",
                message: "Un avis modéré a été publié sur iliprestō.",
            };
        case "hide":
            return {
                title: "Avis masqué",
                message: "Un avis a été masqué par l’équipe de modération.",
            };
        case "reject":
            return {
                title: "Avis rejeté",
                message: "Un avis a été rejeté car il ne respecte pas les règles iliprestō.",
            };
        case "request_correction":
            return {
                title: "Correction d’avis demandée",
                message: "L’équipe iliprestō demande une correction avant publication de l’avis.",
            };
    }
}
exports.adminModerateReviewV2 = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const actorId = requireAuthUid(request);
    const actorRoles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    (0, roles_1.requireAnyRole)(actorRoles, ["moderator", "admin", "superadmin"], "Only moderators and admins can moderate reviews");
    const reviewId = normalizeString(request.data?.reviewId);
    const decision = assertDecision(request.data?.decision);
    const note = normalizeString(request.data?.note).slice(0, 800);
    if (!reviewId) {
        throw new https_1.HttpsError("invalid-argument", "reviewId is required");
    }
    try {
        const reviewRef = firestore_1.db.collection(REVIEWS_COLLECTION).doc(reviewId);
        const reviewSnap = await reviewRef.get();
        if (!reviewSnap.exists) {
            throw new https_1.HttpsError("not-found", "Review not found");
        }
        const reviewData = (reviewSnap.data() ?? {});
        const reviewerId = normalizeString(reviewData.reviewerId);
        const reviewedUserId = normalizeString(reviewData.reviewedUserId);
        const offerId = normalizeString(reviewData.offerId);
        const actionRef = firestore_1.db.collection(REVIEW_MODERATION_ACTIONS_COLLECTION).doc();
        const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        await firestore_1.db.runTransaction(async (transaction) => {
            transaction.set(reviewRef, {
                ...patchForDecision(decision, note),
                lastModeratedAt: now,
                lastModeratedBy: actorId,
                lastModerationDecision: decision,
            }, { merge: true });
            transaction.set(actionRef, {
                reviewId,
                decision,
                note: note || null,
                actorId,
                actorRoles,
                reviewerId: reviewerId || null,
                reviewedUserId: reviewedUserId || null,
                offerId: offerId || null,
                createdAt: now,
            });
        });
        const notification = userNotificationForDecision(decision);
        await Promise.all(Array.from(new Set([reviewerId, reviewedUserId]))
            .filter(Boolean)
            .map((userId) => (0, push_1.createInAppNotification)({
            notificationId: `review_moderation_${reviewId}_${decision}_${userId}`,
            userId,
            title: notification.title,
            message: notification.message,
            type: "review_moderation_decision",
            routeName: `/profile/${encodeURIComponent(userId)}`,
            offerId: offerId || undefined,
            data: { reviewId, decision },
        })));
        logger_1.logger.info("marketplace_review_admin_moderated", {
            reviewId,
            decision,
            actorId,
            reviewerId,
            reviewedUserId,
            offerId,
        });
        return { ok: true, reviewId, decision };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to moderate review v2");
    }
});
//# sourceMappingURL=reviews_admin_v2.js.map