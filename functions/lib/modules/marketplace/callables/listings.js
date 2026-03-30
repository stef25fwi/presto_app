"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.incrementListingView = exports.submitListingDraft = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const firestore_1 = require("../../../core/firestore");
const rate_limit_1 = require("../../../core/rate_limit");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const push_1 = require("../../notifications/push");
const analytics_1 = require("../services/analytics");
const media_1 = require("./media");
const moderation_1 = require("../services/moderation");
const recaptcha_1 = require("../services/recaptcha");
const errors_1 = require("../services/errors");
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
async function normalizeListingMediaForSubmission({ ownerId, media, }) {
    return Promise.all(media.map(async (entry) => {
        const storagePath = normalizeString(entry.storagePath);
        const mimeType = normalizeString(entry.mimeType).toLowerCase();
        if (!storagePath) {
            throw new https_1.HttpsError("invalid-argument", "Media storagePath is required");
        }
        if (storagePath.toLowerCase().endsWith(".webp") && mimeType === "image/webp") {
            return entry;
        }
        const processed = await (0, media_1.processOfferPhotoStoragePath)({
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
async function loadDraftSnapshot(draftId) {
    const primaryRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingDraftsV2).doc(draftId);
    const primarySnap = await primaryRef.get();
    if (primarySnap.exists) {
        return primarySnap;
    }
    const legacyRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingDrafts).doc(draftId);
    const legacySnap = await legacyRef.get();
    if (legacySnap.exists) {
        return legacySnap;
    }
    throw new https_1.HttpsError("not-found", "Draft not found");
}
async function ensureCategoryAndCityAreActive(categoryId, cityId) {
    const [categorySnap, citySnap] = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.categories).doc(categoryId).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.cities).doc(cityId).get(),
    ]);
    if (!categorySnap.exists || categorySnap.data()?.isActive === false) {
        throw new https_1.HttpsError("failed-precondition", "Category is invalid or inactive");
    }
    if (!citySnap.exists || citySnap.data()?.isActive === false) {
        throw new https_1.HttpsError("failed-precondition", "City is invalid or inactive");
    }
    return {
        category: categorySnap.data() ?? {},
        city: citySnap.data() ?? {},
    };
}
async function readOwnerSignals(ownerId, normalizedTitle) {
    const [userSnap, listingSnap] = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(ownerId).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.listings).where("ownerId", "==", ownerId).limit(20).get(),
    ]);
    const userData = (userSnap.data() ?? {});
    const now = Date.now();
    const recentListingCount = listingSnap.docs.filter((doc) => {
        const createdAt = doc.data().createdAt;
        if (createdAt instanceof firebase_admin_1.default.firestore.Timestamp) {
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
exports.submitListingDraft = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const ownerId = requireAuthUid(request);
    const draftId = normalizeString(request.data?.draftId);
    const recaptchaToken = normalizeString(request.data?.recaptchaToken);
    if (!draftId) {
        throw new https_1.HttpsError("invalid-argument", "draftId is required");
    }
    const rateAllowed = await (0, rate_limit_1.canProceedRateLimited)("listing_submit", ownerId, 5, 60 * 60 * 1000);
    if (!rateAllowed) {
        throw new https_1.HttpsError("resource-exhausted", "Too many listing submissions, please retry later");
    }
    const recaptcha = await (0, recaptcha_1.verifyRecaptchaAssessment)({
        token: recaptchaToken,
        expectedAction: "listing_submit",
        userId: ownerId,
    });
    if (!recaptcha.allowed) {
        throw new https_1.HttpsError("permission-denied", "reCAPTCHA assessment rejected the listing submission");
    }
    try {
        const config = await (0, moderation_1.loadModerationConfig)();
        const draftSnap = await loadDraftSnapshot(draftId);
        const draftData = (draftSnap.data() ?? {});
        if (normalizeString(draftData.ownerId) !== ownerId) {
            throw new https_1.HttpsError("permission-denied", "You do not own this draft");
        }
        const validated = (0, listings_1.validateListingDraftPayload)(draftData, config.maxMediaCount || env_1.MARKETPLACE_MAX_MEDIA_COUNT);
        const refsData = await ensureCategoryAndCityAreActive(validated.categoryId, validated.cityId);
        const ownerSignals = await readOwnerSignals(ownerId, validated.title.toLowerCase());
        const listingId = draftId;
        const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId);
        const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        const expiresAt = firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() + 90 * 24 * 60 * 60 * 1000));
        const cityData = refsData.city;
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
        const evaluation = await (0, moderation_1.evaluateListingRisk)({
            ownerId,
            title: validated.title,
            description: validated.description,
            media: normalizedMedia,
            ownerSignals: {
                ...ownerSignals,
                lastRecaptchaScore: recaptcha.score,
            },
        });
        const publication = await (0, moderation_1.persistModerationResult)({
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
            await (0, push_1.createInAppNotification)({
                notificationId: `listing_approved_${listingId}`,
                userId: ownerId,
                title: "Annonce publiee",
                message: validated.title,
                type: "listing_approved",
                routeName,
                offerId: listingId,
            });
            await (0, analytics_1.trackProductEventBackend)({
                eventName: "listing_published",
                userId: ownerId,
                listingId,
                params: {
                    moderation_status: publication.moderationStatus,
                    recaptcha_score: recaptcha.score,
                },
            });
        }
        else if (publication.status === "rejected") {
            await (0, push_1.createInAppNotification)({
                notificationId: `listing_rejected_${listingId}`,
                userId: ownerId,
                title: "Annonce rejetee",
                message: evaluation.moderationReason,
                type: "listing_rejected",
                routeName,
                offerId: listingId,
            });
            await (0, analytics_1.trackProductEventBackend)({
                eventName: "listing_rejected",
                userId: ownerId,
                listingId,
                params: {
                    moderation_status: publication.moderationStatus,
                    risk_score: evaluation.riskScore,
                },
            });
        }
        else {
            await (0, push_1.createInAppNotification)({
                notificationId: `listing_manual_review_${listingId}`,
                userId: ownerId,
                title: "Annonce en revue",
                message: "Votre annonce est en attente de moderation.",
                type: "manual_review_required",
                routeName,
                offerId: listingId,
            });
        }
        await (0, analytics_1.trackProductEventBackend)({
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
        logger_1.logger.info("marketplace_listing_submitted", {
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
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to submit listing draft");
    }
});
exports.incrementListingView = (0, https_1.onCall)({ region: env_1.PROJECT_REGION }, async (request) => {
    const listingId = normalizeString(request.data?.listingId);
    const viewerKey = normalizeString(request.data?.viewerKey);
    const viewerId = normalizeString(request.auth?.uid) || viewerKey;
    if (!listingId || !viewerId) {
        throw new https_1.HttpsError("invalid-argument", "listingId and viewer identity are required");
    }
    const allowed = await (0, rate_limit_1.canProceedRateLimited)("listing_view", `${listingId}:${viewerId}`, 1, 24 * 60 * 60 * 1000);
    if (!allowed) {
        return { ok: true, deduplicated: true };
    }
    const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId);
    const listingSnap = await listingRef.get();
    if (!listingSnap.exists) {
        throw new https_1.HttpsError("not-found", "Listing not found");
    }
    const listingData = (listingSnap.data() ?? {});
    if (normalizeString(listingData.status) !== "active" || normalizeString(listingData.visibility) !== "public") {
        throw new https_1.HttpsError("failed-precondition", "Listing is not public");
    }
    await listingRef.set({
        viewCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, analytics_1.trackProductEventBackend)({
        eventName: "listing_view",
        userId: normalizeString(request.auth?.uid) || undefined,
        listingId,
        params: {
            source: normalizeString(request.data?.source) || "unknown",
        },
    });
    return { ok: true, deduplicated: false };
});
//# sourceMappingURL=listings.js.map