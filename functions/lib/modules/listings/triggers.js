"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onListingPublished = exports.onOfferUpdated = exports.onOfferCreated = void 0;
exports.buildListingRouteUrl = buildListingRouteUrl;
exports.getPostalCode = getPostalCode;
exports.getSubCategory = getSubCategory;
exports.shouldNotifyUserForFavoriteListing = shouldNotifyUserForFavoriteListing;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const env_1 = require("../../config/env");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
const push_1 = require("../notifications/push");
function getOwnerId(data) {
    if (!data)
        return "";
    return String(data.owner_id || data.ownerId || data.userId || data.uid || "");
}
function getTitle(data) {
    return String(data?.title || "Votre annonce");
}
function buildListingRouteUrl(sourceCollection, sourceId) {
    if (sourceCollection === constants_1.COLLECTIONS.listings) {
        return `${env_1.APP_BASE_URL}/listings/${sourceId}`;
    }
    return `${env_1.APP_BASE_URL}/offers/${sourceId}`;
}
function getCategory(data) {
    return String(data?.category || "").trim();
}
function getPostalCode(data) {
    return String(data?.postalCode || data?.codePostal || data?.zipCode || data?.cp || "").trim();
}
function getSubCategory(data) {
    return String(data?.subCategory || data?.subcategory || "").trim();
}
function normalizeAlertToken(value) {
    return String(value || "").trim().toLowerCase();
}
function splitFavoriteSubcategoryLabel(value) {
    const raw = String(value || "").trim();
    if (!raw)
        return null;
    const separator = raw.includes(" — ")
        ? " — "
        : raw.includes(" - ")
            ? " - "
            : raw.includes("/")
                ? "/"
                : "";
    if (!separator)
        return null;
    const [left, ...rest] = raw.split(separator);
    if (!left || rest.length === 0)
        return null;
    const right = rest.join(separator).trim();
    const category = left.trim();
    if (!category || !right)
        return null;
    return { category, subcategory: right };
}
function normalizeStringList(value) {
    if (!Array.isArray(value))
        return [];
    return value
        .map((entry) => String(entry || "").trim())
        .filter((entry) => entry.length > 0);
}
function shouldNotifyUserForFavoriteListing({ userData, listingCategory, listingSubCategory, listingPostalCode, }) {
    const normalizedCategory = normalizeAlertToken(listingCategory);
    if (!normalizedCategory)
        return false;
    const selectedCategories = normalizeStringList(userData.selectedFavoriteCategories);
    const legacyFavorites = normalizeStringList(userData.favoriteCategories);
    const hasCategorySelection = [...selectedCategories, ...legacyFavorites]
        .map((entry) => normalizeAlertToken(entry))
        .includes(normalizedCategory);
    if (!hasCategorySelection) {
        return false;
    }
    // Filtrer par département si l'utilisateur en a sélectionné
    const selectedDepartements = normalizeStringList(userData.selectedFavoriteDepartements);
    if (selectedDepartements.length > 0) {
        const postalCode = (listingPostalCode || '').trim();
        if (postalCode.length >= 2) {
            const listingDept = (postalCode.startsWith('97') || postalCode.startsWith('98'))
                ? postalCode.substring(0, 3)
                : postalCode.substring(0, 2);
            if (!selectedDepartements.includes(listingDept)) {
                return false;
            }
        }
    }
    // Sans sous-catégorie sur l'annonce, on notifie tous les abonnés à la catégorie.
    const normalizedListingSubCategory = normalizeAlertToken(listingSubCategory);
    if (!normalizedListingSubCategory) {
        return true;
    }
    const selectedSubcategories = normalizeStringList(userData.selectedFavoriteSubcategories);
    const categoryScopedSubcategories = selectedSubcategories
        .map(splitFavoriteSubcategoryLabel)
        .filter((entry) => entry != null)
        .filter((entry) => normalizeAlertToken(entry.category) === normalizedCategory)
        .map((entry) => normalizeAlertToken(entry.subcategory));
    // Si l'utilisateur n'a pas restreint la catégorie par sous-catégorie,
    // on conserve le comportement historique (alerte catégorie).
    if (categoryScopedSubcategories.length === 0) {
        return true;
    }
    return categoryScopedSubcategories.includes(normalizedListingSubCategory);
}
async function notifyFavoriteCategoryUsers({ offerId, offerData, ownerId, }) {
    const category = getCategory(offerData);
    if (!category)
        return;
    const subCategory = getSubCategory(offerData);
    const [selectedSnap, legacySnap] = await Promise.all([
        firestore_2.db.collection(constants_1.COLLECTIONS.users)
            .where("selectedFavoriteCategories", "array-contains", category)
            .limit(500)
            .get(),
        firestore_2.db.collection(constants_1.COLLECTIONS.users)
            .where("favoriteCategories", "array-contains", category)
            .limit(500)
            .get(),
    ]);
    const recipients = new Set();
    for (const doc of [...selectedSnap.docs, ...legacySnap.docs]) {
        if (!doc.id || doc.id === ownerId)
            continue;
        const userData = (doc.data() ?? {});
        if (shouldNotifyUserForFavoriteListing({
            userData,
            listingCategory: category,
            listingSubCategory: subCategory,
            listingPostalCode: getPostalCode(offerData),
        })) {
            recipients.add(doc.id);
        }
    }
    if (recipients.size === 0)
        return;
    const title = getTitle(offerData);
    const routeName = buildListingRouteUrl(constants_1.COLLECTIONS.listings, offerId)
        .replace(env_1.APP_BASE_URL, "");
    for (const userId of recipients) {
        const notificationId = `notif_favorite_listing_${offerId}_${userId}`;
        await Promise.all([
            (0, push_1.createInAppNotification)({
                notificationId,
                userId,
                title: `Nouvelle annonce dans ${category}`,
                message: title,
                type: "favorite_listing_new",
                routeName,
                offerId,
                data: {
                    category,
                },
            }),
            (0, push_1.sendPushToUser)({
                userId,
                topic: "favorites",
                title: `Nouvelle annonce dans ${category}`,
                body: title,
                routeName,
                channelId: "ilipresto_activity",
                collapseKey: `favorite_offer_${offerId}`,
                data: {
                    type: "favorite_listing_new",
                    offerId,
                    category,
                    notificationId,
                },
            }),
        ]);
    }
}
function normalizeStatus(data) {
    return String(data?.status || "").trim().toLowerCase();
}
function isPublishedStatus(data) {
    const status = normalizeStatus(data);
    return status === "published" || status === "active" || data?.isActive === true;
}
function isSubmittedStatus(data) {
    const status = normalizeStatus(data);
    return status === "submitted" || status === "in_moderation" || status === "pending_moderation";
}
function isRejectedStatus(data) {
    const status = normalizeStatus(data);
    return status === "rejected" || status === "refused" || status === "declined";
}
async function emitListingEvent({ eventName, sourceCollection, sourceId, ownerId, dedupeSeed, payload, }) {
    if (!ownerId)
        return;
    const userSnap = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(ownerId).get();
    const email = String(userSnap.data()?.email || "").trim();
    if (!email)
        return;
    const now = Date.now();
    const eventId = `evt_${eventName.replace(/\./g, "_")}_${sourceId}_${now}`;
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: eventName,
        source_collection: sourceCollection,
        source_id: sourceId,
        recipient_user_id: ownerId,
        dedupe_key: (0, hash_1.sha256)(dedupeSeed),
        occurred_at: now,
        payload: {
            recipient_email: email,
            ...payload,
        },
        status: "created",
    });
}
exports.onOfferCreated = (0, firestore_1.onDocumentCreated)("offers/{offerId}", async (event) => {
    const after = event.data?.data();
    if (!after)
        return;
    const offerId = event.params.offerId;
    const ownerId = getOwnerId(after);
    if (isSubmittedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.submitted",
            sourceCollection: constants_1.LEGACY_COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.submitted:${offerId}`,
            payload: {
                listingTitle: getTitle(after),
            },
        });
        return;
    }
    if (isPublishedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.published",
            sourceCollection: constants_1.LEGACY_COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.published:${offerId}`,
            payload: {
                listingTitle: getTitle(after),
                listingUrl: buildListingRouteUrl(constants_1.LEGACY_COLLECTIONS.offers, offerId),
            },
        });
        await notifyFavoriteCategoryUsers({
            offerId,
            offerData: after,
            ownerId,
        });
    }
});
exports.onOfferUpdated = (0, firestore_1.onDocumentUpdated)("offers/{offerId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after)
        return;
    const offerId = event.params.offerId;
    const ownerId = getOwnerId(after);
    if (!isSubmittedStatus(before) && isSubmittedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.submitted",
            sourceCollection: constants_1.LEGACY_COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.submitted:${offerId}:${normalizeStatus(after)}`,
            payload: {
                listingTitle: getTitle(after),
            },
        });
    }
    if (!isPublishedStatus(before) && isPublishedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.published",
            sourceCollection: constants_1.LEGACY_COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.published:${offerId}:${normalizeStatus(after)}`,
            payload: {
                listingTitle: getTitle(after),
                listingUrl: buildListingRouteUrl(constants_1.LEGACY_COLLECTIONS.offers, offerId),
            },
        });
        await notifyFavoriteCategoryUsers({
            offerId,
            offerData: after,
            ownerId,
        });
    }
    if (!isRejectedStatus(before) && isRejectedStatus(after)) {
        await emitListingEvent({
            eventName: "listing.rejected",
            sourceCollection: constants_1.LEGACY_COLLECTIONS.offers,
            sourceId: offerId,
            ownerId,
            dedupeSeed: `listing.rejected:${offerId}:${normalizeStatus(after)}`,
            payload: {
                listingTitle: getTitle(after),
                rejectionReason: String(after.rejectionReason || after.moderationReason || after.rejectedReason || "Annonce non conforme à la charte"),
                editUrl: buildListingRouteUrl(constants_1.LEGACY_COLLECTIONS.offers, offerId),
            },
        });
    }
});
exports.onListingPublished = (0, firestore_1.onDocumentUpdated)("listings/{listingId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const listingId = event.params.listingId;
    if (!after || isPublishedStatus(before) || !isPublishedStatus(after))
        return;
    await emitListingEvent({
        eventName: "listing.published",
        sourceCollection: constants_1.COLLECTIONS.listings,
        sourceId: listingId,
        ownerId: getOwnerId(after),
        dedupeSeed: `listing.published:${listingId}`,
        payload: {
            listingTitle: getTitle(after),
            listingUrl: buildListingRouteUrl(constants_1.COLLECTIONS.listings, listingId),
        },
    });
    await notifyFavoriteCategoryUsers({
        offerId: listingId,
        offerData: after,
        ownerId: getOwnerId(after),
    });
});
//# sourceMappingURL=triggers.js.map