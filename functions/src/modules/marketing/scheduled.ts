import { Query, QueryDocumentSnapshot } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { APP_BASE_URL } from "../../config/env";
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

function readTimestampMs(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) return value;
  if (value instanceof Date) return value.getTime();
  if (typeof value === "object" && value && "toMillis" in value) {
    const candidate = (value as { toMillis?: () => number }).toMillis?.();
    if (typeof candidate === "number" && Number.isFinite(candidate) && candidate > 0) return candidate;
  }
  return 0;
}

function normalizeEmail(value: unknown): string {
  return String(value || "").trim().toLowerCase();
}

function extractFirstName(value: unknown): string {
  return String(value || "").trim().split(" ")[0] || "";
}

function buildMissingProfileFields(userData: Record<string, unknown>): string[] {
  const missing: string[] = [];
  if (!String(userData.displayName || userData.display_name || "").trim()) missing.push("nom");
  if (!String(userData.phone || userData.phoneNumber || userData.phone_number || "").trim()) missing.push("telephone");
  if (!String(userData.city || userData.cityName || userData.city_name || "").trim()) missing.push("ville");
  return missing;
}

async function processProfileIncompleteReminders(now: number): Promise<void> {
  const lowerBound = now - 14 * 24 * 60 * 60 * 1000;
  const upperBound = now - 24 * 60 * 60 * 1000;
  let query: Query = db
    .collection(COLLECTIONS.notificationPreferences)
    .where("created_at", ">=", lowerBound)
    .where("created_at", "<=", upperBound)
    .orderBy("created_at")
    .limit(200);
  let lastDoc: QueryDocumentSnapshot | undefined;

  while (true) {
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      lastDoc = doc;
      const userId = doc.id;
      const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
      const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
      const recipientEmail = String(userData.email || "").trim().toLowerCase();
      if (!recipientEmail) continue;

      const missingFields = buildMissingProfileFields(userData);
      if (missingFields.length === 0) continue;

      const bucket = Math.floor(now / (7 * 24 * 60 * 60 * 1000));
      const eventId = `evt_profile_incomplete_reminder_${userId}_${bucket}`;
      await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "profile.incomplete.reminder",
        source_collection: COLLECTIONS.users,
        source_id: userId,
        recipient_user_id: userId,
        dedupe_key: sha256(`profile.incomplete.reminder:${userId}:${bucket}`),
        occurred_at: now,
        payload: {
          recipient_email: recipientEmail,
          firstName: String(userData.displayName || userData.display_name || "").trim().split(" ")[0] || "",
          completionUrl: "https://presto.app/mon-compte",
          missingFieldsSummary: missingFields.join(", "),
        },
        status: "created",
      }, { merge: true });
    }

    if (snap.size < 200 || !lastDoc) break;
    query = db
      .collection(COLLECTIONS.notificationPreferences)
      .where("created_at", ">=", lowerBound)
      .where("created_at", "<=", upperBound)
      .orderBy("created_at")
      .startAfter(lastDoc)
      .limit(200);
  }
}

async function processReactivation30Days(now: number): Promise<void> {
  const threshold = now - 30 * 24 * 60 * 60 * 1000;
  let query: Query = db
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
      const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
      const recipientEmail = String(userData.email || "").trim().toLowerCase();
      if (!recipientEmail) continue;
      if (String(userData.status || "").trim().toLowerCase() === "deleted") continue;

      const lastActivityAt = Math.max(
        readTimestampMs(userData.lastLoginAt),
        readTimestampMs(userData.last_login_at),
        readTimestampMs(userData.updatedAt),
        readTimestampMs(userData.updated_at),
      );
      if (!lastActivityAt || lastActivityAt > threshold) continue;

      const bucket = Math.floor(now / (30 * 24 * 60 * 60 * 1000));
      const eventId = `evt_growth_reactivation_30_days_${userId}_${bucket}`;
      await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "growth.reactivation.30_days",
        source_collection: COLLECTIONS.users,
        source_id: userId,
        recipient_user_id: userId,
        dedupe_key: sha256(`growth.reactivation.30_days:${userId}:${bucket}`),
        occurred_at: now,
        payload: {
          recipient_email: recipientEmail,
          firstName: String(userData.displayName || userData.display_name || "").trim().split(" ")[0] || "",
          dashboardUrl: "https://presto.app/mon-compte",
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

export const enqueueProfileIncompleteReminderEmails = onSchedule("every day 10:30", async () => {
  await processProfileIncompleteReminders(Date.now());
});

export const enqueueReactivation30DaysEmails = onSchedule("every day 09:30", async () => {
  await processReactivation30Days(Date.now());
});

async function countRecentPublishedListingsForCity(city: string, sinceMs: number): Promise<number> {
  const [listingsSnap, offersSnap] = await Promise.all([
    db.collection(COLLECTIONS.listings).where("city", "==", city).limit(100).get(),
    db.collection(COLLECTIONS.offers).where("city", "==", city).limit(100).get(),
  ]);

  const matches = [...listingsSnap.docs, ...offersSnap.docs].filter((doc) => {
    const data = doc.data() as Record<string, unknown>;
    const status = String(data.status || "").trim().toLowerCase();
    if (status !== "published" && status !== "active") return false;
    const publishedAt = readTimestampMs(data.published_at ?? data.publishedAt ?? data.created_at ?? data.createdAt);
    return publishedAt >= sinceMs;
  });

  return matches.length;
}

export const enqueueNearbyNewListingsEmails = onSchedule("every day 08:30", async () => {
  const now = Date.now();
  const sinceMs = now - 24 * 60 * 60 * 1000;
  let query: Query = db
    .collection(COLLECTIONS.notificationPreferences)
    .where("email.marketing.enabled", "==", true)
    .orderBy("__name__")
    .limit(100);
  let lastDoc: QueryDocumentSnapshot | undefined;

  while (true) {
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      lastDoc = doc;
      const userId = doc.id;
      const prefData = doc.data() as Record<string, unknown>;
      const savedSearchMode = String(((prefData.email as Record<string, unknown> | undefined)?.saved_searches as Record<string, unknown> | undefined)?.mode || "off");
      if (savedSearchMode === "off") continue;

      const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
      const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
      const recipientEmail = normalizeEmail(userData.email);
      const city = String(userData.city || "").trim();
      if (!recipientEmail || !city) continue;

      const matchCount = await countRecentPublishedListingsForCity(city, sinceMs);
      if (matchCount <= 0) continue;

      const bucket = Math.floor(now / (24 * 60 * 60 * 1000));
      const eventId = `evt_growth_nearby_new_listings_${userId}_${bucket}`;
      await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "growth.nearby_new_listings",
        source_collection: COLLECTIONS.listings,
        source_id: city,
        recipient_user_id: userId,
        dedupe_key: sha256(`growth.nearby_new_listings:${userId}:${city}:${bucket}`),
        occurred_at: now,
        payload: {
          recipient_email: recipientEmail,
          firstName: extractFirstName(userData.displayName || userData.display_name),
          city,
          matchCount,
          resultsUrl: `${APP_BASE_URL}/offers?city=${encodeURIComponent(city)}`,
        },
        status: "created",
      }, { merge: true });
    }

    if (snap.size < 100 || !lastDoc) break;
    query = db
      .collection(COLLECTIONS.notificationPreferences)
      .where("email.marketing.enabled", "==", true)
      .orderBy("__name__")
      .startAfter(lastDoc)
      .limit(100);
  }
});