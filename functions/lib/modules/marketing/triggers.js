"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNewsletterCampaignUpdated = exports.onNewsletterCampaignCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
const system_messages_1 = require("../marketplace/services/system_messages");
function getCampaignTitle(data) {
    return String(data.title || data.newsletter_title || "Newsletter PRESTO").trim();
}
function getCampaignUrl(data) {
    return String(data.url || data.newsletter_url || "").trim();
}
async function emitNewsletterCampaign(campaignId, data) {
    const newsletterTitle = getCampaignTitle(data);
    const newsletterUrl = getCampaignUrl(data);
    if (!newsletterUrl)
        return;
    let query = firestore_2.db
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
            const userSnap = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(userId).get();
            const userData = userSnap.data() ?? {};
            const recipientEmail = String(userData.email || "").trim().toLowerCase();
            if (!recipientEmail)
                continue;
            const eventId = `evt_marketing_newsletter_${campaignId}_${userId}`;
            await Promise.all([
                firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
                    event_id: eventId,
                    event_name: "marketing.newsletter.monthly",
                    source_collection: constants_1.COLLECTIONS.newsletterCampaigns,
                    source_id: campaignId,
                    recipient_user_id: userId,
                    dedupe_key: (0, hash_1.sha256)(`marketing.newsletter.monthly:${campaignId}:${userId}`),
                    occurred_at: Number(data.published_at || data.updated_at || Date.now()),
                    payload: {
                        recipient_email: recipientEmail,
                        newsletterTitle,
                        newsletterUrl,
                    },
                    status: "created",
                }, { merge: true }),
                (0, system_messages_1.sendTeamBroadcastMessage)({
                    userId,
                    messageId: `newsletter_${campaignId}_${userId}`,
                    body: newsletterTitle,
                    campaignTitle: newsletterTitle,
                    campaignUrl: newsletterUrl || undefined,
                }),
            ]);
        }
        if (snap.size < 200 || !lastDoc)
            break;
        query = firestore_2.db
            .collection(constants_1.COLLECTIONS.notificationPreferences)
            .where("email.marketing.enabled", "==", true)
            .orderBy("__name__")
            .startAfter(lastDoc)
            .limit(200);
    }
}
exports.onNewsletterCampaignCreated = (0, firestore_1.onDocumentCreated)(`${constants_1.COLLECTIONS.newsletterCampaigns}/{campaignId}`, async (event) => {
    const data = (event.data?.data() ?? {});
    if (String(data.status || "draft").trim().toLowerCase() !== "published")
        return;
    await emitNewsletterCampaign(String(event.params.campaignId || ""), data);
});
exports.onNewsletterCampaignUpdated = (0, firestore_1.onDocumentUpdated)(`${constants_1.COLLECTIONS.newsletterCampaigns}/{campaignId}`, async (event) => {
    const before = (event.data?.before.data() ?? {});
    const after = (event.data?.after.data() ?? {});
    const previousStatus = String(before.status || "draft").trim().toLowerCase();
    const nextStatus = String(after.status || "draft").trim().toLowerCase();
    if (nextStatus !== "published" || previousStatus === "published")
        return;
    await emitNewsletterCampaign(String(event.params.campaignId || ""), after);
});
//# sourceMappingURL=triggers.js.map