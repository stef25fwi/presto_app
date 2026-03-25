import { QueryDocumentSnapshot } from "firebase-admin/firestore";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

type NewsletterCampaign = {
  title?: string;
  newsletter_title?: string;
  url?: string;
  newsletter_url?: string;
  status?: string;
  published_at?: number;
  updated_at?: number;
};

function getCampaignTitle(data: NewsletterCampaign): string {
  return String(data.title || data.newsletter_title || "Newsletter PRESTO").trim();
}

function getCampaignUrl(data: NewsletterCampaign): string {
  return String(data.url || data.newsletter_url || "").trim();
}

async function emitNewsletterCampaign(campaignId: string, data: NewsletterCampaign): Promise<void> {
  const newsletterTitle = getCampaignTitle(data);
  const newsletterUrl = getCampaignUrl(data);
  if (!newsletterUrl) return;

  let query = db
    .collection(COLLECTIONS.notificationPreferences)
    .where("email.marketing.enabled", "==", true)
    .orderBy("__name__")
    .limit(200);
  let lastDoc: QueryDocumentSnapshot | undefined;

  while (true) {
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      lastDoc = doc;
      const userId = doc.id;
      const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
      const userData = userSnap.data() ?? {};
      const recipientEmail = String(userData.email || "").trim().toLowerCase();
      if (!recipientEmail) continue;

      const eventId = `evt_marketing_newsletter_${campaignId}_${userId}`;
      await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "marketing.newsletter.monthly",
        source_collection: COLLECTIONS.newsletterCampaigns,
        source_id: campaignId,
        recipient_user_id: userId,
        dedupe_key: sha256(`marketing.newsletter.monthly:${campaignId}:${userId}`),
        occurred_at: Number(data.published_at || data.updated_at || Date.now()),
        payload: {
          recipient_email: recipientEmail,
          newsletterTitle,
          newsletterUrl,
        },
        status: "created",
      }, { merge: true });
    }

    if (snap.size < 200 || !lastDoc) break;
    query = db
      .collection(COLLECTIONS.notificationPreferences)
      .where("email.marketing.enabled", "==", true)
      .orderBy("__name__")
      .startAfter(lastDoc)
      .limit(200);
  }
}

export const onNewsletterCampaignCreated = onDocumentCreated(`${COLLECTIONS.newsletterCampaigns}/{campaignId}`, async (event) => {
  const data = (event.data?.data() ?? {}) as NewsletterCampaign;
  if (String(data.status || "draft").trim().toLowerCase() !== "published") return;
  await emitNewsletterCampaign(String(event.params.campaignId || ""), data);
});

export const onNewsletterCampaignUpdated = onDocumentUpdated(`${COLLECTIONS.newsletterCampaigns}/{campaignId}`, async (event) => {
  const before = (event.data?.before.data() ?? {}) as NewsletterCampaign;
  const after = (event.data?.after.data() ?? {}) as NewsletterCampaign;
  const previousStatus = String(before.status || "draft").trim().toLowerCase();
  const nextStatus = String(after.status || "draft").trim().toLowerCase();
  if (nextStatus !== "published" || previousStatus === "published") return;
  await emitNewsletterCampaign(String(event.params.campaignId || ""), after);
});