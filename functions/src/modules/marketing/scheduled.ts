import { Query, QueryDocumentSnapshot } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

type OnboardingStage = {
  eventName: "marketing.onboarding.d1_due" | "marketing.onboarding.d3_due" | "marketing.onboarding.d7_due";
  minAgeMs: number;
  maxAgeMs: number;
};

const ONBOARDING_STAGES: OnboardingStage[] = [
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

async function emitOnboardingEvent(userId: string, eventName: OnboardingStage["eventName"], occurredAt: number): Promise<void> {
  const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
  const userData = userSnap.data() ?? {};
  const recipientEmail = String(userData.email || "").trim().toLowerCase();
  if (!recipientEmail) return;

  const payload: Record<string, unknown> = {
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
  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: eventName,
    source_collection: COLLECTIONS.notificationPreferences,
    source_id: userId,
    recipient_user_id: userId,
    dedupe_key: sha256(`${eventName}:${userId}`),
    occurred_at: occurredAt,
    payload,
    status: "created",
  }, { merge: true });
}

async function processStage(stage: OnboardingStage, now: number): Promise<void> {
  const lowerBound = now - stage.maxAgeMs;
  const upperBound = now - stage.minAgeMs;
  let query: Query = db
    .collection(COLLECTIONS.notificationPreferences)
    .where("email.marketing.enabled", "==", true)
    .where("created_at", ">=", lowerBound)
    .where("created_at", "<", upperBound)
    .orderBy("created_at")
    .limit(200);
  let lastDoc: QueryDocumentSnapshot | undefined;

  while (true) {
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      lastDoc = doc;
      await emitOnboardingEvent(doc.id, stage.eventName, now);
    }

    if (snap.size < 200 || !lastDoc) break;
    query = db
      .collection(COLLECTIONS.notificationPreferences)
      .where("email.marketing.enabled", "==", true)
      .where("created_at", ">=", lowerBound)
      .where("created_at", "<", upperBound)
      .orderBy("created_at")
      .startAfter(lastDoc)
      .limit(200);
  }
}

export const enqueueMarketingOnboardingEmails = onSchedule("every day 09:00", async () => {
  const now = Date.now();
  for (const stage of ONBOARDING_STAGES) {
    await processStage(stage, now);
  }
});