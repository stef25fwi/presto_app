"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.closeOfferWithReason = exports.deleteListing = exports.getListingContactPhone = exports.incrementListingView = exports.submitListingDraft = exports.updateListingDraftMedia = exports.createListingDraft = void 0;
exports.buildListingDraftDocumentPath = buildListingDraftDocumentPath;
exports.buildListingDocumentPath = buildListingDocumentPath;
exports.assertDraftOwnership = assertDraftOwnership;
exports.assertCategoryAndCityConfigured = assertCategoryAndCityConfigured;
exports.buildAutoPublishAfterForSubmission = buildAutoPublishAfterForSubmission;
exports.closeOrDeleteListingForOwner = closeOrDeleteListingForOwner;
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
const system_messages_1 = require("../services/system_messages");
const recaptcha_1 = require("../services/recaptcha");
const recaptcha_2 = require("../services/recaptcha");
const errors_1 = require("../services/errors");
const roles_1 = require("../services/roles");
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
function normalizeDisplayName(...values) {
    for (const value of values) {
        const normalized = normalizeString(value);
        if (normalized) {
            return normalized;
        }
    }
    return "Annonceur iliprestō";
}
function buildListingDraftDocumentPath(draftId) {
    return `${constants_1.COLLECTIONS.listingDrafts}/${draftId}`;
}
function buildListingDocumentPath(listingId) {
    return `${constants_1.COLLECTIONS.listings}/${listingId}`;
}
function assertDraftOwnership(ownerId, draftData) {
    if (normalizeString(draftData.ownerId) !== ownerId) {
        throw new https_1.HttpsError("permission-denied", "You do not own this draft");
    }
}
function assertCategoryAndCityConfigured({ categoryExists, categoryActive, cityExists, cityActive, }) {
    if (!categoryExists || !categoryActive || !cityExists || !cityActive) {
        throw new https_1.HttpsError("failed-precondition", "Category or city is not configured");
    }
}
function readListingOwnerId(data) {
    for (const field of ["ownerId", "userId", "uid"]) {
        const value = normalizeString(data[field]);
        if (value) {
            return value;
        }
    }
    return "";
}
function sanitizeDraftPayload(rawDraft, ownerId) {
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
    const sanitized = {
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
function collectListingMediaStoragePaths(data) {
    const media = Array.isArray(data.media) ? data.media : [];
    return Array.from(new Set(media
        .map((entry) => normalizeString(entry.storagePath))
        .filter((storagePath) => storagePath.length > 0)));
}
function collectListingImageUrls(media) {
    return Array.from(new Set(media
        .map((entry) => normalizeString(entry.downloadUrl || entry.thumbnailUrl))
        .filter((url) => url.length > 0)));
}
function extractDialingCode(rawPhone) {
    const compact = normalizeString(rawPhone).replace(/[\s().-]+/g, "");
    if (!compact)
        return "";
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
    if (fallback?.[1])
        return fallback[1];
    const localPrefixToDialingCode = {
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
    if (compact.length === 10 && compact.startsWith("0"))
        return "+33";
    if (compact.length === 9 && (compact.startsWith("6") || compact.startsWith("7"))) {
        return "+33";
    }
    return "";
}
function buildAutoPublishAfterForSubmission({ mediaCount, nowMs = Date.now(), }) {
    if (mediaCount <= 0) {
        return null;
    }
    return firebase_admin_1.default.firestore.Timestamp.fromMillis(nowMs + 30 * 1000);
}
function departmentFromPostalCode(postalCode) {
    const cp = postalCode.trim();
    if (cp.length < 2)
        return "";
    if (cp.startsWith("97") || cp.startsWith("98")) {
        return cp.length >= 3 ? cp.slice(0, 3) : cp;
    }
    return cp.slice(0, 2);
}
function buildCategoryKeywords(label, categoryId) {
    const tokens = `${label} ${categoryId}`
        .toLowerCase()
        .split(/[^a-z0-9]+/i)
        .map((value) => value.trim())
        .filter((value) => value.length >= 2);
    return Array.from(new Set(tokens)).slice(0, 20);
}
async function normalizeListingMediaForSubmission({ ownerId, draftId, listingId, media, }) {
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
async function loadDraftSnapshot(draftId) {
    const primaryRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingDrafts).doc(draftId);
    const primarySnap = await primaryRef.get();
    if (primarySnap.exists) {
        return primarySnap;
    }
    const legacyRef = firestore_1.db.collection(constants_1.LEGACY_COLLECTIONS.listingDrafts).doc(draftId);
    const legacySnap = await legacyRef.get();
    if (legacySnap.exists) {
        return legacySnap;
    }
    throw new https_1.HttpsError("not-found", "Draft not found");
}
async function ensureCategoryAndCityAreResolvable(validated) {
    const [categorySnap, citySnap] = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.categories).doc(validated.categoryId).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.cities).doc(validated.cityId).get(),
    ]);
    // Catégorie : doit exister dans la taxonomie — on ne crée pas de documents
    // fantômes depuis des labels libres envoyés par le client.
    if (!categorySnap.exists || categorySnap.data()?.isActive === false) {
        throw new https_1.HttpsError("failed-precondition", "Category is invalid or inactive");
    }
    const categoryData = categorySnap.data();
    // Ville inactive (désactivée par un admin) : on rejette plutôt que de
    // réécrire isActive:true via merge, ce qui annulerait la désactivation.
    if (citySnap.exists && citySnap.data()?.isActive === false) {
        throw new https_1.HttpsError("failed-precondition", "City is invalid or inactive");
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
        throw new https_1.HttpsError("failed-precondition", "City is invalid or inactive");
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
    await firestore_1.db.collection(constants_1.COLLECTIONS.cities).doc(validated.cityId).set(fallbackCityData);
    return {
        category: categoryData,
        city: fallbackCityData,
    };
}
async function readOwnerSignals(ownerId, normalizedTitle, excludeListingId) {
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
        if (excludeListingId && doc.id === excludeListingId)
            return false;
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
async function loadOwnerPublicIdentity(ownerId) {
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(ownerId).get();
    const userData = (userSnap.data() ?? {});
    // Tente d'abord les champs Firestore
    const displayName = normalizeDisplayName(userData.pseudo, userData.displayName, userData.userName, userData.user_name, userData.name);
    const avatarUrl = normalizeString(userData.avatarUrl || userData.photoURL);
    const verified = userData.isProfileVerified === true ||
        userData.isVerified === true ||
        userData.verified === true;
    // Fallback Auth uniquement si displayName manquant
    if (displayName === "Annonceur iliprestō") {
        const authRecord = await firebase_admin_1.default.auth().getUser(ownerId).catch(() => null);
        const emailPrefix = normalizeString(authRecord?.email).split("@").shift() ?? "";
        return {
            displayName: normalizeDisplayName(authRecord?.displayName, emailPrefix),
            avatarUrl: avatarUrl || normalizeString(authRecord?.photoURL),
            verified,
        };
    }
    return { displayName, avatarUrl, verified };
}
exports.createListingDraft = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const ownerId = requireAuthUid(request);
    const rawDraft = (request.data?.draft ?? {});
    const draft = sanitizeDraftPayload(rawDraft, ownerId);
    try {
        (0, listings_1.validateListingDraftPayload)(draft, env_1.MARKETPLACE_MAX_MEDIA_COUNT);
        const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        const draftRef = firestore_1.db.collection(constants_1.COLLECTIONS.listingDrafts).doc();
        await draftRef.set({
            ...draft,
            createdAt: now,
            updatedAt: now,
        });
        await (0, analytics_1.trackProductEventBackend)({
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
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to create listing draft");
    }
});
exports.updateListingDraftMedia = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const ownerId = requireAuthUid(request);
    const draftId = normalizeString(request.data?.draftId);
    if (!draftId) {
        throw new https_1.HttpsError("invalid-argument", "draftId is required");
    }
    try {
        const media = (0, listings_1.validateListingMedia)(request.data?.media, env_1.MARKETPLACE_MAX_MEDIA_COUNT);
        const draftSnap = await loadDraftSnapshot(draftId);
        const draftData = (draftSnap.data() ?? {});
        assertDraftOwnership(ownerId, draftData);
        await draftSnap.ref.set({
            media,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return { ok: true, draftId, mediaCount: media.length };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to update listing draft media");
    }
});
exports.submitListingDraft = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const deploymentRevision = "2026-05-19-recaptcha-env-refresh";
    void deploymentRevision;
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
    if ((0, recaptcha_2.shouldRejectListingSubmissionForRecaptcha)(recaptcha)) {
        throw new https_1.HttpsError("permission-denied", "reCAPTCHA assessment rejected the listing submission");
    }
    if (!recaptcha.allowed) {
        logger_1.logger.warn("marketplace_listing_submit_low_recaptcha_score", {
            ownerId,
            draftId,
            score: recaptcha.score,
            reasons: recaptcha.reasons,
            action: recaptcha.action,
        });
    }
    try {
        const config = await (0, moderation_1.loadModerationConfig)();
        const draftSnap = await loadDraftSnapshot(draftId);
        const draftData = (draftSnap.data() ?? {});
        assertDraftOwnership(ownerId, draftData);
        const validated = (0, listings_1.validateListingDraftPayload)(draftData, config.maxMediaCount || env_1.MARKETPLACE_MAX_MEDIA_COUNT);
        const refsData = await ensureCategoryAndCityAreResolvable(validated);
        const listingId = draftId;
        const ownerSignals = await readOwnerSignals(ownerId, validated.title.toLowerCase(), listingId);
        const ownerIdentity = await loadOwnerPublicIdentity(ownerId);
        const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId);
        const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
        const expiresAt = firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() + 90 * 24 * 60 * 60 * 1000));
        const cityData = refsData.city;
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
            phone: firebase_admin_1.default.firestore.FieldValue.delete(),
            telephone: firebase_admin_1.default.firestore.FieldValue.delete(),
            contactPhone: firebase_admin_1.default.firestore.FieldValue.delete(),
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
        const privateContactRef = firestore_1.db.collection("listingPrivateContacts").doc(listingId);
        if (validated.phone) {
            await privateContactRef.set({
                listingId,
                ownerId,
                phone: validated.phone,
                hidePhone: validated.hidePhone,
                createdAt: now,
                updatedAt: now,
            }, { merge: true });
        }
        else {
            await privateContactRef.delete().catch(() => undefined);
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
        // Keep photo listings in pending briefly so users see the validation step
        // before the scheduler flips them to public/active.
        const autoPublishAfter = buildAutoPublishAfterForSubmission({
            mediaCount: normalizedMedia.length,
        });
        const publication = await (0, moderation_1.persistModerationResult)({
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
            await (0, system_messages_1.sendListingModerationSystemMessage)({
                ownerId,
                listingId,
                listingTitle: validated.title,
                body: evaluation.autoFlags.includes("banned_term")
                    ? "Bonjour, votre annonce contient un texte qui ne respecte pas nos règles de publication. Merci de modifier le titre ou la description avant de la soumettre à nouveau."
                    : "Bonjour, votre annonce n’a pas pu être publiée car une image ajoutée ne respecte pas nos règles de modération. Merci de remplacer cette photo par une image claire, conforme et sans contenu sensible. Votre annonce pourra ensuite être soumise à nouveau.",
            });
            await (0, push_1.createInAppNotification)({
                notificationId: `listing_rejected_${listingId}`,
                userId: ownerId,
                title: "Annonce rejetee",
                message: evaluation.moderationUserMessage || evaluation.moderationReason,
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
        else if (publication.moderationStatus !== "approved") {
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
exports.incrementListingView = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
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
exports.getListingContactPhone = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const listingId = normalizeString(request.data?.listingId);
    if (!listingId) {
        throw new https_1.HttpsError("invalid-argument", "listingId is required");
    }
    const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId);
    const [listingSnap, privateContactSnap] = await Promise.all([
        listingRef.get(),
        firestore_1.db.collection("listingPrivateContacts").doc(listingId).get(),
    ]);
    if (!listingSnap.exists) {
        throw new https_1.HttpsError("not-found", "Listing not found");
    }
    const listingData = (listingSnap.data() ?? {});
    const status = normalizeString(listingData.status).toLowerCase();
    const visibility = normalizeString(listingData.visibility).toLowerCase();
    const hidePhone = listingData.hidePhone === true;
    const uid = normalizeString(request.auth?.uid);
    const ownerId = readListingOwnerId(listingData);
    const isOwner = uid.length > 0 && uid === ownerId;
    const isPublic = status === "active" && visibility === "public";
    if (!isPublic && !isOwner) {
        throw new https_1.HttpsError("permission-denied", "Listing is not publicly visible");
    }
    const privateData = (privateContactSnap.data() ?? {});
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
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
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
const VALID_JOB_DONE_REASONS = ['found_on_ilipresto', 'found_provider_elsewhere'];
/**
 * Checks if the deletion reason corresponds to a "job done" scenario
 * where the listing should be kept visible with an overlay instead of hard-deleted.
 * Accepts a structured enum value OR falls back to textual detection for backward compatibility.
 */
function isJobDoneReason(reason, jobDone) {
    if (jobDone === true)
        return true;
    if (!reason)
        return false;
    // Structured enum check
    if (VALID_JOB_DONE_REASONS.includes(reason))
        return true;
    // Legacy textual detection (backward compat)
    const normalized = reason
        .trim()
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/['']/g, "'")
        .replace(/\s+/g, " ");
    const foundOnIliPresto = normalized.includes("trouve quelqu") && normalized.includes("ilipresto");
    const foundProvider = normalized.includes("deja trouve") && normalized.includes("prestataire");
    return foundOnIliPresto || foundProvider;
}
function isFoundOnIliPrestoReason(reason) {
    if (!reason)
        return false;
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
async function closeOrDeleteListingForOwner({ actorId, listingId, reason, jobDone, allowAdminDelete = false, }) {
    const listingRef = firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId);
    const listingSnap = await listingRef.get();
    if (!listingSnap.exists) {
        throw new https_1.HttpsError("not-found", "Listing not found");
    }
    const listingData = (listingSnap.data() ?? {});
    const listingOwnerId = readListingOwnerId(listingData);
    const isOwnerDelete = listingOwnerId === actorId;
    const isAdminDelete = allowAdminDelete && !isOwnerDelete;
    if (!isOwnerDelete && !isAdminDelete) {
        throw new https_1.HttpsError("permission-denied", "You do not own this listing");
    }
    const previousStatus = normalizeString(listingData.status) || "unknown";
    const listingTitle = normalizeString(listingData.title) || "votre annonce";
    const mediaStoragePaths = collectListingMediaStoragePaths(listingData);
    if (isJobDoneReason(reason, jobDone === true)) {
        // Keep the listing public for 10h so browse queries can still fetch it
        // and render the job-done overlay before it disappears client-side.
        const visibleUntil = firebase_admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() + JOB_DONE_OVERLAY_HOURS * 60 * 60 * 1000));
        const reviewRequested = isFoundOnIliPrestoReason(reason);
        await listingRef.update({
            status: "active",
            visibility: "public",
            isActive: true,
            isPublished: true,
            closedReason: reason,
            closedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            selectedUserId: null,
            reviewRequested,
            reviewSubmitted: false,
            deletedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            deletedReason: reason,
            archiveReason: reason,
            jobDoneOverlayVisible: true,
            jobDoneOverlayVisibleUntil: visibleUntil,
            removeFromBrowseAt: visibleUntil,
        });
        logger_1.logger.info("marketplace_listing_marked_job_done", {
            listingId,
            ownerId: listingOwnerId,
            actorId,
            previousStatus,
            reason,
        });
        return { ok: true, listingId, jobDone: true };
    }
    const bucket = firebase_admin_1.default.storage().bucket();
    await Promise.all(mediaStoragePaths.map(async (storagePath) => {
        try {
            await bucket.file(storagePath).delete();
        }
        catch {
            // Best effort: media cleanup must not block listing deletion.
        }
    }));
    // Hard-delete the listing and related documents.
    const batch = firestore_1.db.batch();
    // Archive avant hard-delete (traçabilité modération, RGPD, analytics)
    const archiveRef = firestore_1.db.collection('deletedListings').doc(listingId);
    batch.set(archiveRef, {
        ...listingData,
        deletedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        deletedBy: actorId,
        deletedForOwnerId: listingOwnerId,
        deletedByAdmin: isAdminDelete,
        deletedReason: reason || 'user_request',
        originalListingId: listingId,
    });
    batch.delete(listingRef);
    batch.delete(firestore_1.db.collection(constants_1.COLLECTIONS.listingModeration).doc(listingId));
    batch.delete(firestore_1.db.collection(constants_1.COLLECTIONS.listingDrafts).doc(listingId));
    batch.delete(firestore_1.db.collection(constants_1.LEGACY_COLLECTIONS.listingDrafts).doc(listingId));
    await batch.commit();
    logger_1.logger.info("marketplace_listing_deleted", {
        listingId,
        ownerId: listingOwnerId,
        actorId,
        adminDelete: isAdminDelete,
        previousStatus,
        reason: reason || "none",
    });
    if (isAdminDelete && listingOwnerId) {
        await (0, system_messages_1.sendTeamBroadcastMessage)({
            userId: listingOwnerId,
            messageId: `listing_deleted_${listingId}`,
            body: `Bonjour, votre annonce "${listingTitle}" a ete supprimee par l'equipe ilipresto.`,
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
exports.deleteListing = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const actorId = requireAuthUid(request);
    const actorRoles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    const allowAdminDelete = actorRoles.includes("admin") || actorRoles.includes("superadmin");
    const listingId = normalizeString(request.data?.listingId);
    const reason = typeof request.data?.reason === "string"
        ? request.data.reason.trim().slice(0, 500)
        : undefined;
    if (!listingId) {
        throw new https_1.HttpsError("invalid-argument", "listingId is required");
    }
    try {
        return await closeOrDeleteListingForOwner({
            actorId,
            listingId,
            reason,
            jobDone: request.data?.jobDone === true,
            allowAdminDelete,
        });
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to delete listing");
    }
});
exports.closeOfferWithReason = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const actorId = requireAuthUid(request);
    const listingId = normalizeString(request.data?.offerId || request.data?.listingId);
    const reason = typeof request.data?.reason === "string"
        ? request.data.reason.trim().slice(0, 500)
        : undefined;
    if (!listingId) {
        throw new https_1.HttpsError("invalid-argument", "offerId is required");
    }
    if (!reason) {
        throw new https_1.HttpsError("invalid-argument", "reason is required");
    }
    try {
        return await closeOrDeleteListingForOwner({
            actorId,
            listingId,
            reason,
            jobDone: request.data?.jobDone === true,
        });
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to close listing");
    }
});
//# sourceMappingURL=listings.js.map