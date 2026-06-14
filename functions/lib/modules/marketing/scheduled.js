"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enqueueNearbyNewListingsEmails = exports.enqueueReactivation30DaysEmails = exports.enqueueProfileIncompleteReminderEmails = exports.enqueueMarketingOnboardingEmails = void 0;
exports.countRecentPublishedListingRecords = countRecentPublishedListingRecords;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
const ONBOARDING_STAGES = [
    {
        eventName: "marketing.onboarding.d1_due",
        minAgeMs: 1 * 24 * 60 * 60 * 1000,
        maxAgeMs: 2 * 24 * 60 * 60 * 1000,
    },
    {
        eventName: "marketing.onboarding.d3_due",
        minAgeMs: 3 * 24 * 60 * 60 * 1000,
        maxAgeMs: 4 * 24 * 60 * 60 * 1000,
    },
    {
        eventName: "marketing.onboarding.d7_due",
        minAgeMs: 7 * 24 * 60 * 60 * 1000,
        maxAgeMs: 8 * 24 * 60 * 60 * 1000,
    },
];
async function emitOnboardingEvent(userId, eventName, occurredAt) {
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
    const userData = userSnap.data() ?? {};
    const recipientEmail = String(userData.email || "").trim().toLowerCase();
    if (!recipientEmail)
        return;
    const payload = {
        recipient_email: recipientEmail,
        firstName: String(userData.displayName || userData.display_name || "").split(" ")[0] || "",
    };
    if (eventName === "marketing.onboarding.d1_due") {
        payload.dashboardUrl = "https://ilipresto.fr/mon-compte";
    }
    if (eventName === "marketing.onboarding.d3_due") {
        payload.createListingUrl = "https://ilipresto.fr/publier";
    }
    if (eventName === "marketing.onboarding.d7_due") {
        payload.exploreUrl = "https://ilipresto.fr/offers";
    }
    const eventId = `evt_${eventName.replace(/\./g, "_")}_${userId}`;
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: eventName,
        source_collection: constants_1.COLLECTIONS.notificationPreferences,
        source_id: userId,
        recipient_user_id: userId,
        dedupe_key: (0, hash_1.sha256)(`${eventName}:${userId}`),
        occurred_at: occurredAt,
        payload,
        status: "created",
    }, { merge: true });
}
async function processStage(stage, now) {
    const lowerBound = now - stage.maxAgeMs;
    const upperBound = now - stage.minAgeMs;
    let query = firestore_1.db
        .collection(constants_1.COLLECTIONS.notificationPreferences)
        .where("email.marketing.enabled", "==", true)
        .where("created_at", ">=", lowerBound)
        .where("created_at", "<", upperBound)
        .orderBy("created_at")
        .limit(200);
    let lastDoc;
    while (true) {
        const snap = await query.get();
        if (snap.empty)
            break;
        for (const doc of snap.docs) {
            lastDoc = doc;
            await emitOnboardingEvent(doc.id, stage.eventName, now);
        }
        if (snap.size < 200 || !lastDoc)
            break;
        query = firestore_1.db
            .collection(constants_1.COLLECTIONS.notificationPreferences)
            .where("email.marketing.enabled", "==", true)
            .where("created_at", ">=", lowerBound)
            .where("created_at", "<", upperBound)
            .orderBy("created_at")
            .startAfter(lastDoc)
            .limit(200);
    }
}
exports.enqueueMarketingOnboardingEmails = (0, scheduler_1.onSchedule)("every day 09:00", async () => {
    const now = Date.now();
    for (const stage of ONBOARDING_STAGES) {
        await processStage(stage, now);
    }
});
function readTimestampMs(value) {
    if (typeof value === "number" && Number.isFinite(value) && value > 0)
        return value;
    if (value instanceof Date)
        return value.getTime();
    if (typeof value === "object" && value && "toMillis" in value) {
        const candidate = value.toMillis?.();
        if (typeof candidate === "number" && Number.isFinite(candidate) && candidate > 0)
            return candidate;
    }
    return 0;
}
function normalizeEmail(value) {
    return String(value || "").trim().toLowerCase();
}
function extractFirstName(value) {
    return String(value || "").trim().split(" ")[0] || "";
}
function buildMissingProfileFields(userData) {
    const missing = [];
    if (!String(userData.displayName || userData.display_name || "").trim())
        missing.push("nom");
    if (!String(userData.phone || userData.phoneNumber || userData.phone_number || "").trim())
        missing.push("telephone");
    if (!String(userData.city || userData.cityName || userData.city_name || "").trim())
        missing.push("ville");
    return missing;
}
async function processProfileIncompleteReminders(now) {
    const lowerBound = now - 14 * 24 * 60 * 60 * 1000;
    const upperBound = now - 24 * 60 * 60 * 1000;
    let query = firestore_1.db
        .collection(constants_1.COLLECTIONS.notificationPreferences)
        .where("created_at", ">=", lowerBound)
        .where("created_at", "<=", upperBound)
        .orderBy("created_at")
        .limit(200);
    let lastDoc;
    while (true) {
        const snap = await query.get();
        if (snap.empty)
            break;
        for (const doc of snap.docs) {
            lastDoc = doc;
            const userId = doc.id;
            const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
            const userData = (userSnap.data() ?? {});
            const recipientEmail = String(userData.email || "").trim().toLowerCase();
            if (!recipientEmail)
                continue;
            const missingFields = buildMissingProfileFields(userData);
            if (missingFields.length === 0)
                continue;
            const bucket = Math.floor(now / (7 * 24 * 60 * 60 * 1000));
            const eventId = `evt_profile_incomplete_reminder_${userId}_${bucket}`;
            await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
                event_id: eventId,
                event_name: "profile.incomplete.reminder",
                source_collection: constants_1.COLLECTIONS.users,
                source_id: userId,
                recipient_user_id: userId,
                dedupe_key: (0, hash_1.sha256)(`profile.incomplete.reminder:${userId}:${bucket}`),
                occurred_at: now,
                payload: {
                    recipient_email: recipientEmail,
                    firstName: String(userData.displayName || userData.display_name || "").trim().split(" ")[0] || "",
                    completionUrl: "https://ilipresto.fr/mon-compte",
                    missingFieldsSummary: missingFields.join(", "),
                },
                status: "created",
            }, { merge: true });
        }
        if (snap.size < 200 || !lastDoc)
            break;
        query = firestore_1.db
            .collection(constants_1.COLLECTIONS.notificationPreferences)
            .where("created_at", ">=", lowerBound)
            .where("created_at", "<=", upperBound)
            .orderBy("created_at")
            .startAfter(lastDoc)
            .limit(200);
    }
}
async function processReactivation30Days(now) {
    const threshold = now - 30 * 24 * 60 * 60 * 1000;
    let query = firestore_1.db
        .collection(constants_1.COLLECTIONS.notificationPreferences)
        .where("email.marketing.enabled", "==", true)
        .orderBy("__name__")
        .limit(200);
    let lastDoc;
    while (true) {
        const snap = await query.get();
        if (snap.empty)
            break;
        for (const doc of snap.docs) {
            lastDoc = doc;
            const userId = doc.id;
            const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
            const userData = (userSnap.data() ?? {});
            const recipientEmail = String(userData.email || "").trim().toLowerCase();
            if (!recipientEmail)
                continue;
            if (String(userData.status || "").trim().toLowerCase() === "deleted")
                continue;
            const lastActivityAt = Math.max(readTimestampMs(userData.lastLoginAt), readTimestampMs(userData.last_login_at), readTimestampMs(userData.updatedAt), readTimestampMs(userData.updated_at));
            if (!lastActivityAt || lastActivityAt > threshold)
                continue;
            const bucket = Math.floor(now / (30 * 24 * 60 * 60 * 1000));
            const eventId = `evt_growth_reactivation_30_days_${userId}_${bucket}`;
            await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
                event_id: eventId,
                event_name: "growth.reactivation.30_days",
                source_collection: constants_1.COLLECTIONS.users,
                source_id: userId,
                recipient_user_id: userId,
                dedupe_key: (0, hash_1.sha256)(`growth.reactivation.30_days:${userId}:${bucket}`),
                occurred_at: now,
                payload: {
                    recipient_email: recipientEmail,
                    firstName: String(userData.displayName || userData.display_name || "").trim().split(" ")[0] || "",
                    dashboardUrl: "https://ilipresto.fr/mon-compte",
                },
                status: "created",
            }, { merge: true });
        }
        if (snap.size < 200 || !lastDoc)
            break;
        query = firestore_1.db
            .collection(constants_1.COLLECTIONS.notificationPreferences)
            .where("email.marketing.enabled", "==", true)
            .orderBy("__name__")
            .startAfter(lastDoc)
            .limit(200);
    }
}
exports.enqueueProfileIncompleteReminderEmails = (0, scheduler_1.onSchedule)("every day 10:30", async () => {
    await processProfileIncompleteReminders(Date.now());
});
exports.enqueueReactivation30DaysEmails = (0, scheduler_1.onSchedule)("every day 09:30", async () => {
    await processReactivation30Days(Date.now());
});
async function countRecentPublishedListingsForCity(city, sinceMs) {
    const listingsSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.listings).where("city", "==", city).limit(100).get();
    return countRecentPublishedListingRecords(listingsSnap.docs.map((doc) => doc.data()), sinceMs);
}
function countRecentPublishedListingRecords(records, sinceMs) {
    return records.filter((data) => {
        const status = String(data.status || "").trim().toLowerCase();
        if (status !== "published" && status !== "active")
            return false;
        const publishedAt = readTimestampMs(data.published_at ?? data.publishedAt ?? data.created_at ?? data.createdAt);
        return publishedAt >= sinceMs;
    }).length;
}
exports.enqueueNearbyNewListingsEmails = (0, scheduler_1.onSchedule)("every day 08:30", async () => {
    const now = Date.now();
    const sinceMs = now - 24 * 60 * 60 * 1000;
    let query = firestore_1.db
        .collection(constants_1.COLLECTIONS.notificationPreferences)
        .where("email.marketing.enabled", "==", true)
        .orderBy("__name__")
        .limit(100);
    let lastDoc;
    while (true) {
        const snap = await query.get();
        if (snap.empty)
            break;
        for (const doc of snap.docs) {
            lastDoc = doc;
            const userId = doc.id;
            const prefData = doc.data();
            const savedSearchMode = String(prefData.email?.saved_searches?.mode || "off");
            if (savedSearchMode === "off")
                continue;
            const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
            const userData = (userSnap.data() ?? {});
            const recipientEmail = normalizeEmail(userData.email);
            const city = String(userData.city || "").trim();
            if (!recipientEmail || !city)
                continue;
            const matchCount = await countRecentPublishedListingsForCity(city, sinceMs);
            if (matchCount <= 0)
                continue;
            const bucket = Math.floor(now / (24 * 60 * 60 * 1000));
            const eventId = `evt_growth_nearby_new_listings_${userId}_${bucket}`;
            await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
                event_id: eventId,
                event_name: "growth.nearby_new_listings",
                source_collection: constants_1.COLLECTIONS.listings,
                source_id: city,
                recipient_user_id: userId,
                dedupe_key: (0, hash_1.sha256)(`growth.nearby_new_listings:${userId}:${city}:${bucket}`),
                occurred_at: now,
                payload: {
                    recipient_email: recipientEmail,
                    firstName: extractFirstName(userData.displayName || userData.display_name),
                    city,
                    matchCount,
                    resultsUrl: `${env_1.APP_BASE_URL}/offers?city=${encodeURIComponent(city)}`,
                },
                status: "created",
            }, { merge: true });
        }
        if (snap.size < 100 || !lastDoc)
            break;
        query = firestore_1.db
            .collection(constants_1.COLLECTIONS.notificationPreferences)
            .where("email.marketing.enabled", "==", true)
            .orderBy("__name__")
            .startAfter(lastDoc)
            .limit(100);
    }
});
//# sourceMappingURL=scheduled.js.map