"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.reviewListingPhoto = exports.logAdminAction = exports.applyUserRoleClaims = void 0;
exports.buildListingPatchForPhotoReview = buildListingPatchForPhotoReview;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const push_1 = require("../../notifications/push");
const admin_audit_1 = require("../services/admin_audit");
const roles_1 = require("../services/roles");
const errors_1 = require("../services/errors");
const system_messages_1 = require("../services/system_messages");
const listings_1 = require("../validators/listings");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
function resolveActorRole(actorRoles) {
    const ordered = ["superadmin", "admin", "moderator", "pro", "user"];
    return ordered.find((role) => actorRoles.includes(role)) ?? "user";
}
function normalizeString(value) {
    return String(value ?? "").trim();
}
function readInt(value) {
    return typeof value === "number" && Number.isFinite(value)
        ? Math.trunc(value)
        : Number.parseInt(String(value ?? "0"), 10) || 0;
}
function readStringList(value) {
    if (!Array.isArray(value)) {
        return [];
    }
    return value
        .map((entry) => normalizeString(entry))
        .filter(Boolean)
        .filter((entry, index, all) => all.indexOf(entry) === index);
}
function removeFromList(values, target) {
    return values.filter((value) => value !== target);
}
function buildListingPatchForPhotoReview({ decision, listingData, imageUrl, reason, }) {
    const moderation = (listingData.moderation ?? {});
    const imageCount = readInt(listingData.imageCount) || readStringList(listingData.imageUrls).length;
    const approvedImageCount = readInt(listingData.approvedImageCount);
    const rejectedImageCount = readInt(listingData.rejectedImageCount);
    const pendingHumanReviewCount = readInt(listingData.pendingHumanReviewCount);
    const pendingReviewImages = removeFromList(readStringList(listingData.pendingReviewImages), imageUrl);
    const approvedImageUrls = readStringList(listingData.approvedImageUrls);
    const rejectedImages = readStringList(listingData.rejectedImages);
    const textStatus = normalizeString(moderation.textStatus);
    if (decision === "approved") {
        const nextApprovedImageUrls = imageUrl
            ? Array.from(new Set([...approvedImageUrls, imageUrl]))
            : approvedImageUrls;
        const nextApprovedImageCount = approvedImageCount + (imageUrl && !approvedImageUrls.includes(imageUrl) ? 1 : 0);
        const nextPendingCount = Math.max(0, pendingHumanReviewCount - 1);
        const canPublish = nextPendingCount === 0 &&
            rejectedImageCount === 0 &&
            (imageCount === 0 || nextApprovedImageCount >= imageCount) &&
            textStatus === "approved";
        return {
            approvedImageCount: nextApprovedImageCount,
            pendingHumanReviewCount: nextPendingCount,
            pendingReviewImages,
            approvedImageUrls: nextApprovedImageUrls,
            status: canPublish ? "active" : "pending",
            visibility: canPublish ? "public" : "private",
            moderationStatus: canPublish ? "approved" : "manual_review",
            publishedAt: canPublish ? firebase_admin_1.default.firestore.FieldValue.serverTimestamp() : null,
            rejectionReason: null,
            moderation: {
                ...moderation,
                imageStatus: nextPendingCount === 0 ? "approved" : "needs_review",
                finalDecision: canPublish ? "approved" : "needs_review",
                reviewedReason: null,
                checkedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            },
        };
    }
    const nextRejectedImages = imageUrl
        ? Array.from(new Set([...rejectedImages, imageUrl]))
        : rejectedImages;
    return {
        rejectedImageCount: rejectedImageCount + 1,
        pendingHumanReviewCount: Math.max(0, pendingHumanReviewCount - 1),
        pendingReviewImages,
        rejectedImages: nextRejectedImages,
        status: "rejected",
        visibility: "hidden",
        moderationStatus: "rejected",
        autoPublishAfter: null,
        rejectionReason: reason,
        moderationReason: reason,
        moderation: {
            ...moderation,
            imageStatus: "rejected",
            finalDecision: "rejected",
            userMessage: reason,
            reviewedReason: reason,
            checkedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        },
    };
}
exports.applyUserRoleClaims = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const actorId = requireAuthUid(request);
    const actorRoles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    (0, roles_1.requireAnyRole)(actorRoles, ["admin", "superadmin"], "Admin role required");
    try {
        const targetUserId = String(request.data?.targetUserId || "").trim();
        const roles = (0, listings_1.validateRoleAssignment)(request.data?.roles);
        const actorRole = resolveActorRole(actorRoles);
        if (!targetUserId) {
            throw new https_1.HttpsError("invalid-argument", "targetUserId is required");
        }
        if (roles.includes("superadmin") && !actorRoles.includes("superadmin")) {
            throw new https_1.HttpsError("permission-denied", "Only a superadmin can grant the superadmin role");
        }
        await (0, roles_1.syncMarketplaceClaims)({
            targetUserId,
            roles,
        });
        await (0, admin_audit_1.writeAdminActionLog)({
            actorId,
            actorRole,
            actionType: "apply_user_role_claims",
            targetType: "user",
            targetId: targetUserId,
            after: {
                roles,
            },
            metadata: {
                reason: String(request.data?.reason || "").trim() || null,
            },
        });
        return {
            ok: true,
            targetUserId,
            roles,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to apply user role claims");
    }
});
exports.logAdminAction = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const actorId = requireAuthUid(request);
    const actorRoles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    (0, roles_1.requireAnyRole)(actorRoles, ["admin", "superadmin", "moderator"], "Moderator role required");
    try {
        const actorRole = resolveActorRole(actorRoles);
        const actionType = String(request.data?.actionType || "").trim();
        const targetType = String(request.data?.targetType || "").trim();
        const targetId = String(request.data?.targetId || "").trim();
        if (!actionType || !targetType || !targetId) {
            throw new https_1.HttpsError("invalid-argument", "actionType, targetType and targetId are required");
        }
        const adminActionId = await (0, admin_audit_1.writeAdminActionLog)({
            actorId,
            actorRole,
            actionType,
            targetType,
            targetId,
            before: request.data?.before,
            after: request.data?.after,
            metadata: request.data?.metadata,
        });
        return {
            ok: true,
            adminActionId,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to log admin action");
    }
});
exports.reviewListingPhoto = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const actorId = requireAuthUid(request);
    const actorRoles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    (0, roles_1.requireAnyRole)(actorRoles, ["moderator", "admin", "superadmin"], "Moderator role required");
    try {
        const actorRole = resolveActorRole(actorRoles);
        const reviewId = normalizeString(request.data?.reviewId);
        const decision = normalizeString(request.data?.decision);
        const reason = normalizeString(request.data?.reason);
        if (!reviewId || (decision !== "approved" && decision !== "rejected")) {
            throw new https_1.HttpsError("invalid-argument", "reviewId and a valid decision are required");
        }
        if (decision === "rejected" && !reason) {
            throw new https_1.HttpsError("invalid-argument", "reason is required when rejecting a photo");
        }
        const reviewRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingPhotoReviews).doc(reviewId);
        let ownerId = "";
        let listingId = "";
        let listingTitle = "";
        let imageUrl = "";
        await firestore_1.db.runTransaction(async (transaction) => {
            const reviewSnap = await transaction.get(reviewRef);
            if (!reviewSnap.exists) {
                throw new https_1.HttpsError("not-found", "Photo review not found");
            }
            const reviewData = (reviewSnap.data() ?? {});
            if (normalizeString(reviewData.status) !== "pending") {
                throw new https_1.HttpsError("failed-precondition", "Photo review is not pending anymore");
            }
            listingId = normalizeString(reviewData.listingId);
            ownerId = normalizeString(reviewData.ownerId);
            imageUrl = normalizeString(reviewData.imageUrl);
            if (!listingId || !ownerId) {
                throw new https_1.HttpsError("failed-precondition", "Photo review payload is incomplete");
            }
            const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId);
            const moderationRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingModeration).doc(listingId);
            const [listingSnap, moderationSnap] = await Promise.all([
                transaction.get(listingRef),
                transaction.get(moderationRef),
            ]);
            if (!listingSnap.exists) {
                throw new https_1.HttpsError("not-found", "Listing not found");
            }
            const listingData = (listingSnap.data() ?? {});
            listingTitle = normalizeString(listingData.title);
            const listingPatch = buildListingPatchForPhotoReview({
                decision: decision,
                listingData,
                imageUrl,
                reason: reason || "Photo validee par moderation manuelle.",
            });
            const moderationData = (moderationSnap.data() ?? {});
            transaction.set(reviewRef, {
                status: decision,
                reason: reason || null,
                reviewedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                reviewedBy: actorId,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            transaction.set(listingRef, {
                ...listingPatch,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            transaction.set(moderationRef, {
                id: listingId,
                listingId,
                ownerId,
                moderationDecision: decision === "approved"
                    ? normalizeString(listingPatch.moderationStatus) === "approved"
                        ? "approved"
                        : "manual_review"
                    : "rejected",
                moderationReason: decision === "approved"
                    ? "manual_photo_review_approved"
                    : "manual_photo_review_rejected",
                userMessage: decision === "approved"
                    ? normalizeString((moderationData.userMessage ?? "").toString())
                    : reason,
                source: "hybrid",
                reviewedBy: actorId,
                reviewedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        });
        await (0, admin_audit_1.writeAdminActionLog)({
            actorId,
            actorRole,
            actionType: decision === "approved" ? "approve_listing_photo" : "reject_listing_photo",
            targetType: "listingPhotoReview",
            targetId: reviewId,
            metadata: {
                listingId,
                ownerId,
                reason: reason || null,
            },
        });
        if (ownerId) {
            if (decision === "rejected") {
                await (0, system_messages_1.sendListingModerationSystemMessage)({
                    ownerId,
                    listingId,
                    listingTitle,
                    body: "Bonjour, après vérification par notre équipe, une image ajoutée à votre annonce ne respecte pas les règles de publication ilipresto. Merci de modifier votre annonce avec une photo conforme avant une nouvelle soumission.",
                });
            }
            await (0, push_1.createInAppNotification)({
                notificationId: `${decision}_listing_photo_${reviewId}`,
                userId: ownerId,
                title: decision === "approved" ? "Photo validee" : "Photo refusee",
                message: decision === "approved"
                    ? "Une photo de votre annonce a ete validee par l'equipe ilipresto."
                    : (reason || "Une photo de votre annonce a ete refusee par l'equipe ilipresto."),
                type: decision === "approved" ? "listing_approved" : "listing_rejected",
                routeName: `/listings/${encodeURIComponent(listingId)}`,
                offerId: listingId,
            });
        }
        return {
            ok: true,
            reviewId,
            listingId,
            listingTitle,
            decision,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to review listing photo");
    }
});
//# sourceMappingURL=admin.js.map