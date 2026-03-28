"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.reportListing = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const rate_limit_1 = require("../../../core/rate_limit");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const push_1 = require("../../notifications/push");
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
exports.reportListing = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
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
    if (!recaptcha.allowed) {
        throw new https_1.HttpsError("permission-denied", "reCAPTCHA rejected the report");
    }
    try {
        const validated = (0, listings_1.validateListingReportPayload)((request.data ?? {}));
        const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(validated.listingId);
        const reportId = `${validated.listingId}__${reporterId}`;
        const reportRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingReports).doc(reportId);
        const moderationRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingModeration).doc(validated.listingId);
        let reviewTriggered = false;
        let ownerId = "";
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
//# sourceMappingURL=reports.js.map