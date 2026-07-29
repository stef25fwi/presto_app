"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.reportConversationMessage = exports.reportListing = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const rate_limit_1 = require("../../../core/rate_limit");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const hash_1 = require("../../../utils/hash");
const push_1 = require("../../notifications/push");
const participants_1 = require("../../messaging/participants");
const analytics_1 = require("../services/analytics");
const errors_1 = require("../services/errors");
const recaptcha_1 = require("../services/recaptcha");
const listings_1 = require("../validators/listings");
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
function firstNameFromDisplayName(value) {
    const trimmed = value.trim();
    if (!trimmed)
        return "";
    return trimmed.split(/\s+/)[0] || "";
}
async function queryUsersSafely(queryFactory) {
    try {
        const snap = await queryFactory().limit(200).get();
        return snap.docs;
    }
    catch (error) {
        logger_1.logger.warn("marketplace_report_admin_query_failed", {
            error: error instanceof Error ? error.message : String(error),
        });
        return [];
    }
}
async function findModerationRecipients() {
    const [roleArrayDocs, roleFieldDocs, adminDocs, isAdminDocs, superAdminDocs] = await Promise.all([
        queryUsersSafely(() => firestore_1.db.collection(constants_1.COLLECTIONS.users).where("roles", "array-contains-any", ["moderator", "admin", "superadmin"])),
        queryUsersSafely(() => firestore_1.db.collection(constants_1.COLLECTIONS.users).where("role", "in", ["moderator", "admin", "superadmin"])),
        queryUsersSafely(() => firestore_1.db.collection(constants_1.COLLECTIONS.users).where("admin", "==", true)),
        queryUsersSafely(() => firestore_1.db.collection(constants_1.COLLECTIONS.users).where("isAdmin", "==", true)),
        queryUsersSafely(() => firestore_1.db.collection(constants_1.COLLECTIONS.users).where("superadmin", "==", true)),
    ]);
    const byId = new Map();
    for (const snap of [
        ...roleArrayDocs,
        ...roleFieldDocs,
        ...adminDocs,
        ...isAdminDocs,
        ...superAdminDocs,
    ]) {
        const userId = snap.id;
        const data = (snap.data() ?? {});
        const email = normalizeString(data.email);
        if (!email) {
            continue;
        }
        const displayName = normalizeString(data.displayName || data.display_name || data.userName || data.name);
        byId.set(userId, {
            userId,
            email,
            firstName: firstNameFromDisplayName(displayName),
        });
    }
    return Array.from(byId.values());
}
async function enqueueAdminReportAlertEmails({ listingId, listingTitle, reportId, reasonCode, reasonText, reporterId, }) {
    const [recipients, reporterSnap] = await Promise.all([
        findModerationRecipients(),
        firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(reporterId).get().catch(() => null),
    ]);
    if (recipients.length === 0) {
        return 0;
    }
    const reporterData = (reporterSnap?.data() ?? {});
    const reporterName = normalizeString(reporterData.displayName || reporterData.display_name || reporterData.userName || reporterData.name) || "Utilisateur PRESTO";
    const reporterEmail = normalizeString(reporterData.email);
    const now = Date.now();
    const listingUrl = `https://ilipresto.fr/listings/${encodeURIComponent(listingId)}`;
    const reportUrl = `https://ilipresto.fr/admin/reports/${encodeURIComponent(reportId)}`;
    await Promise.all(recipients.map((recipient) => {
        const eventId = `evt_listing_report_admin_alert_${reportId}_${recipient.userId}`;
        return firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
            event_id: eventId,
            event_name: "listing.reported.admin_alert",
            source_collection: constants_1.COLLECTIONS.listingReports,
            source_id: reportId,
            actor_user_id: reporterId,
            recipient_user_id: recipient.userId,
            dedupe_key: (0, hash_1.sha256)(`listing.reported.admin_alert:${reportId}:${recipient.userId}`),
            occurred_at: now,
            payload: {
                recipient_email: recipient.email,
                firstName: recipient.firstName,
                listingId,
                listingTitle: listingTitle || listingId,
                reportId,
                reportReason: reasonCode,
                reportReasonText: reasonText || "(aucun detail fourni)",
                reporterId,
                reporterName,
                reporterEmail,
                listingUrl,
                reportUrl,
            },
            status: "created",
        }, { merge: true });
    }));
    return recipients.length;
}
exports.reportListing = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const reporterId = requireAuthUid(request);
    const recaptchaToken = normalizeString(request.data?.recaptchaToken);
    const rateAllowed = await (0, rate_limit_1.canProceedRateLimited)("listing_report", reporterId, 15, 24 * 60 * 60 * 1000);
    if (!rateAllowed) {
        throw new https_1.HttpsError("resource-exhausted", "Too many reports today");
    }
    const recaptcha = await (0, recaptcha_1.verifyRecaptchaAssessment)({
        token: recaptchaToken,
        expectedAction: "listing_report",
        userId: reporterId,
    });
    if ((0, recaptcha_1.shouldHardRejectForRecaptcha)(recaptcha)) {
        throw new https_1.HttpsError("permission-denied", "reCAPTCHA rejected the report");
    }
    if (!recaptcha.allowed) {
        logger_1.logger.warn("marketplace_listing_report_recaptcha_non_blocking", {
            reporterId,
            score: recaptcha.score,
            reasons: recaptcha.reasons,
            action: recaptcha.action,
            assessed: recaptcha.assessed,
        });
    }
    try {
        const validated = (0, listings_1.validateListingReportPayload)((request.data ?? {}));
        const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(validated.listingId);
        const reportId = `${validated.listingId}__${reporterId}`;
        const reportRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingReports).doc(reportId);
        const moderationRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingModeration).doc(validated.listingId);
        let reviewTriggered = false;
        let ownerId = "";
        let listingTitle = "";
        await firestore_1.db.runTransaction(async (transaction) => {
            const [listingSnap, reportSnap, moderationSnap] = await Promise.all([
                transaction.get(listingRef),
                transaction.get(reportRef),
                transaction.get(moderationRef),
            ]);
            if (!listingSnap.exists) {
                throw new https_1.HttpsError("not-found", "Listing not found");
            }
            if (reportSnap.exists) {
                throw new https_1.HttpsError("already-exists", "You have already reported this listing");
            }
            const listingData = (listingSnap.data() ?? {});
            ownerId = normalizeString(listingData.ownerId);
            listingTitle = normalizeString(listingData.title);
            if (ownerId === reporterId) {
                throw new https_1.HttpsError("failed-precondition", "You cannot report your own listing");
            }
            const newReportCount = Number(listingData.reportCount || 0) + 1;
            transaction.set(reportRef, {
                id: reportId,
                reporterId,
                listingId: validated.listingId,
                reasonCode: validated.reasonCode,
                reasonText: validated.reasonText || null,
                status: "open",
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            transaction.set(listingRef, {
                reportCount: newReportCount,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            if (newReportCount >= env_1.MARKETPLACE_REPORT_REVIEW_THRESHOLD) {
                reviewTriggered = true;
                const currentAutoFlags = Array.isArray(moderationSnap.data()?.autoFlags)
                    ? moderationSnap.data()?.autoFlags
                    : [];
                transaction.set(listingRef, {
                    status: "pending",
                    moderationStatus: "manual_review",
                    visibility: "private",
                    updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
                transaction.set(moderationRef, {
                    id: validated.listingId,
                    listingId: validated.listingId,
                    ownerId,
                    moderationDecision: "manual_review",
                    moderationReason: "report_threshold_reached",
                    autoFlags: Array.from(new Set([...currentAutoFlags, "report_threshold_exceeded"])),
                    updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                    createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        });
        if (reviewTriggered && ownerId) {
            await (0, push_1.createInAppNotification)({
                notificationId: `listing_reported_${validated.listingId}`,
                userId: ownerId,
                title: "Annonce en revue",
                message: "Votre annonce a atteint le seuil de signalements et passe en revue manuelle.",
                type: "listing_reported",
                routeName: `/listings/${encodeURIComponent(validated.listingId)}`,
                offerId: validated.listingId,
            });
        }
        const adminAlertRecipients = await enqueueAdminReportAlertEmails({
            listingId: validated.listingId,
            listingTitle,
            reportId,
            reasonCode: validated.reasonCode,
            reasonText: validated.reasonText || "",
            reporterId,
        }).catch((error) => {
            logger_1.logger.warn("marketplace_listing_report_admin_alert_failed", {
                listingId: validated.listingId,
                reportId,
                error: error instanceof Error ? error.message : String(error),
            });
            return 0;
        });
        await (0, analytics_1.trackProductEventBackend)({
            eventName: "listing_reported",
            userId: reporterId,
            listingId: validated.listingId,
            params: {
                reason_code: validated.reasonCode,
                threshold_triggered: reviewTriggered,
            },
        });
        logger_1.logger.info("marketplace_listing_reported", {
            listingId: validated.listingId,
            reporterId,
            reasonCode: validated.reasonCode,
            reviewTriggered,
            adminAlertRecipients,
        });
        return {
            ok: true,
            reportId,
            reviewTriggered,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to report listing");
    }
});
exports.reportConversationMessage = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const reporterId = requireAuthUid(request);
    const recaptchaToken = normalizeString(request.data?.recaptchaToken);
    const rateAllowed = await (0, rate_limit_1.canProceedRateLimited)("message_report", reporterId, 15, 24 * 60 * 60 * 1000);
    if (!rateAllowed) {
        throw new https_1.HttpsError("resource-exhausted", "Too many reports today");
    }
    const recaptcha = await (0, recaptcha_1.verifyRecaptchaAssessment)({
        token: recaptchaToken,
        expectedAction: "message_report",
        userId: reporterId,
    });
    if ((0, recaptcha_1.shouldHardRejectForRecaptcha)(recaptcha)) {
        throw new https_1.HttpsError("permission-denied", "reCAPTCHA rejected the report");
    }
    if (!recaptcha.allowed) {
        logger_1.logger.warn("marketplace_message_report_recaptcha_non_blocking", {
            reporterId,
            score: recaptcha.score,
            reasons: recaptcha.reasons,
            action: recaptcha.action,
            assessed: recaptcha.assessed,
        });
    }
    try {
        const validated = (0, listings_1.validateConversationReportPayload)((request.data ?? {}));
        const conversationRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(validated.conversationId);
        const conversationSnap = await conversationRef.get();
        if (!conversationSnap.exists) {
            throw new https_1.HttpsError("not-found", "Conversation not found");
        }
        const conversationData = (conversationSnap.data() ?? {});
        const participants = (0, participants_1.readConversationParticipants)(conversationData, {
            conversationId: validated.conversationId,
        });
        if (!participants.includes(reporterId)) {
            throw new https_1.HttpsError("permission-denied", "You are not a participant of this conversation");
        }
        const reportedUserId = participants.find((id) => id !== reporterId) || "";
        if (!reportedUserId) {
            throw new https_1.HttpsError("failed-precondition", "Unable to determine the reported participant");
        }
        const reportId = validated.messageId
            ? `${validated.conversationId}__${validated.messageId}__${reporterId}`
            : `${validated.conversationId}__${reporterId}`;
        const reportRef = firestore_1.db.collection(constants_1.COLLECTIONS.messageReports).doc(reportId);
        const moderationRef = firestore_1.db.collection(constants_1.COLLECTIONS.userModeration).doc(reportedUserId);
        let reviewTriggered = false;
        await firestore_1.db.runTransaction(async (transaction) => {
            const [reportSnap, moderationSnap] = await Promise.all([
                transaction.get(reportRef),
                transaction.get(moderationRef),
            ]);
            if (reportSnap.exists) {
                throw new https_1.HttpsError("already-exists", "You have already reported this");
            }
            transaction.set(reportRef, {
                id: reportId,
                reporterId,
                reportedUserId,
                conversationId: validated.conversationId,
                messageId: validated.messageId || null,
                reasonCode: validated.reasonCode,
                reasonText: validated.reasonText || null,
                status: "open",
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            const moderationData = (moderationSnap.data() ?? {});
            const newReportCount = Number(moderationData.reportCount || 0) + 1;
            const currentAutoFlags = Array.isArray(moderationData.autoFlags)
                ? moderationData.autoFlags
                : [];
            const moderationUpdate = {
                id: reportedUserId,
                userId: reportedUserId,
                reportCount: newReportCount,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            };
            if (newReportCount >= env_1.MARKETPLACE_REPORT_REVIEW_THRESHOLD) {
                reviewTriggered = true;
                moderationUpdate.moderationDecision = "manual_review";
                moderationUpdate.moderationReason = "report_threshold_reached";
                moderationUpdate.autoFlags = Array.from(new Set([...currentAutoFlags, "report_threshold_exceeded"]));
            }
            transaction.set(moderationRef, moderationUpdate, { merge: true });
        });
        if (reviewTriggered) {
            const recipients = await findModerationRecipients();
            await Promise.all(recipients.map((recipient) => (0, push_1.createInAppNotification)({
                notificationId: `message_reported_${reportedUserId}_${recipient.userId}`,
                userId: recipient.userId,
                title: "Utilisateur signalé en messagerie",
                message: "Un utilisateur a atteint le seuil de signalements en messagerie et passe en revue manuelle.",
                type: "message_reported",
                routeName: "/admin",
                conversationId: validated.conversationId,
                data: { reportedUserId },
            })));
        }
        await (0, analytics_1.trackProductEventBackend)({
            eventName: "message_reported",
            userId: reporterId,
            threadId: validated.conversationId,
            params: {
                reason_code: validated.reasonCode,
                threshold_triggered: reviewTriggered,
            },
        });
        logger_1.logger.info("marketplace_message_reported", {
            conversationId: validated.conversationId,
            reporterId,
            reportedUserId,
            reasonCode: validated.reasonCode,
            reviewTriggered,
        });
        return {
            ok: true,
            reportId,
            reviewTriggered,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to report message");
    }
});
//# sourceMappingURL=reports.js.map