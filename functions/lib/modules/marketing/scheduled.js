"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.enqueueMarketingOnboardingEmails = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
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
        payload.dashboardUrl = "https://presto.app/mon-compte";
    }
    if (eventName === "marketing.onboarding.d3_due") {
        payload.createListingUrl = "https://presto.app/publier";
    }
    if (eventName === "marketing.onboarding.d7_due") {
        payload.exploreUrl = "https://presto.app/offers";
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
//# sourceMappingURL=scheduled.js.map