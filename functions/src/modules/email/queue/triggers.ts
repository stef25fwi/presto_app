import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { DomainEventPayload } from "../../../types/events";
import { enqueueEmailJobsFromEvent } from "./enqueue";
import { processEmailJob as processSingleJob } from "./worker";
import { sha256 } from "../../../utils/hash";

const DIGEST_PAGE_SIZE = 60;
const DIGEST_MAX_PAGES_PER_RUN = 6;
const DIGEST_MAX_EVENTS_PER_RUN = 120;
const DIGEST_CURSOR_DOC_ID = "email_digest_scheduler_cursor";
const DIGEST_MAX_MATCHES_PER_USER = 200;
const DIGEST_BATCH_WRITE_SIZE = 100;

interface LocalTimeParts {
  year: number;
  month: number;
  day: number;
  weekday: number;
  hour: number;
  minute: number;
}

function getLocalTimeParts(timezone: string, ts: number): LocalTimeParts | null {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour12: false,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      weekday: "short",
      hour: "2-digit",
      minute: "2-digit",
    }).formatToParts(new Date(ts));

    const map = Object.fromEntries(parts.map((p) => [p.type, p.value]));
    const weekdayMap: Record<string, number> = {
      Sun: 7,
      Mon: 1,
      Tue: 2,
      Wed: 3,
      Thu: 4,
      Fri: 5,
      Sat: 6,
    };

    return {
      year: Number(map.year || 0),
      month: Number(map.month || 0),
      day: Number(map.day || 0),
      weekday: weekdayMap[map.weekday || ""] || 0,
      hour: Number(map.hour || 0),
      minute: Number(map.minute || 0),
    };
  } catch {
    return null;
  }
}

function localDayKey(p: LocalTimeParts): string {
  return `${p.year}-${String(p.month).padStart(2, "0")}-${String(p.day).padStart(2, "0")}`;
}

function localWeekKey(p: LocalTimeParts): string {
  // Weekly digest is emitted on local Monday morning; use local Monday date as bucket.
  return `W-${localDayKey(p)}`;
}

function shouldEmitDigest(mode: "daily" | "weekly", p: LocalTimeParts): { emit: boolean; catchup: boolean } {
  const minuteOfDay = p.hour * 60 + p.minute;
  const primaryStart = 8 * 60;
  const primaryEnd = 8 * 60 + 19;
  const catchupEnd = 20 * 60 + 59;

  const inPrimaryWindow = minuteOfDay >= primaryStart && minuteOfDay <= primaryEnd;
  const inCatchupWindow = minuteOfDay > primaryEnd && minuteOfDay <= catchupEnd;

  if (mode === "daily") {
    if (inPrimaryWindow) return { emit: true, catchup: false };
    if (inCatchupWindow) return { emit: true, catchup: true };
    return { emit: false, catchup: false };
  }

  // Weekly digest only on local Monday, with same primary+catch-up windows.
  if (p.weekday !== 1) return { emit: false, catchup: false };
  if (inPrimaryWindow) return { emit: true, catchup: false };
  if (inCatchupWindow) return { emit: true, catchup: true };
  return { emit: false, catchup: false };
}

function capDigestMatchCount(raw: number): { matchCount: number; rawMatchCount: number; capped: boolean } {
  const safeRaw = Math.max(0, Number.isFinite(raw) ? Math.trunc(raw) : 0);
  if (safeRaw <= DIGEST_MAX_MATCHES_PER_USER) {
    return { matchCount: safeRaw, rawMatchCount: safeRaw, capped: false };
  }
  return { matchCount: DIGEST_MAX_MATCHES_PER_USER, rawMatchCount: safeRaw, capped: true };
}

export const digestTestables = {
  getLocalTimeParts,
  localDayKey,
  localWeekKey,
  shouldEmitDigest,
  capDigestMatchCount,
};

export const enqueueEmailJobsFromEventTrigger = onDocumentCreated("email_events/{eventId}", async (event) => {
  const payload = event.data?.data() as DomainEventPayload | undefined;
  if (!payload) return;
  await enqueueEmailJobsFromEvent(payload);
});

export const processEmailJobTrigger = onDocumentCreated("email_jobs/{jobId}", async (event) => {
  const jobId = event.params.jobId;
  await processSingleJob(jobId);
});

export const processScheduledEmailDigests = onSchedule("every 15 minutes", async () => {
  const now = Date.now();
  const cursorRef = db.collection(COLLECTIONS.systemSettings).doc(DIGEST_CURSOR_DOC_ID);
  const cursorSnap = await cursorRef.get();
  const cursor = String(cursorSnap.data()?.notification_pref_cursor || "");

  let emitted = 0;
  let scanned = 0;
  let pages = 0;
  let lastDocId = cursor;
  let emittedCatchup = 0;
  let cappedUsers = 0;
  let skippedAlreadyExists = 0;

  while (pages < DIGEST_MAX_PAGES_PER_RUN && emitted < DIGEST_MAX_EVENTS_PER_RUN) {
    let query = db.collection(COLLECTIONS.notificationPreferences).orderBy("__name__").limit(DIGEST_PAGE_SIZE);
    if (lastDocId) query = query.startAfter(lastDocId);

    const prefsQ = await query.get();
    if (prefsQ.empty) {
      lastDocId = "";
      break;
    }

    pages += 1;
    scanned += prefsQ.docs.length;

    const pendingEvents: Array<{ eventId: string; payload: Record<string, unknown> }> = [];

    for (const prefDoc of prefsQ.docs) {
      lastDocId = prefDoc.id;

      const prefData = prefDoc.data() as Record<string, unknown>;
      const emailPrefs = (prefData.email as Record<string, unknown> | undefined) || {};
      const savedSearchesPrefs = (emailPrefs.saved_searches as Record<string, unknown> | undefined) || {};
      const mode = String(savedSearchesPrefs.mode || "off");
      if (mode !== "daily" && mode !== "weekly") continue;

      const timezone = String(prefData.timezone || "UTC");
      const parts = getLocalTimeParts(timezone, now);
      if (!parts) continue;
      const window = shouldEmitDigest(mode as "daily" | "weekly", parts);
      if (!window.emit) continue;

      const userId = prefDoc.id;
      const userSnap = await db.collection(COLLECTIONS.users).doc(userId).get();
      const userData = userSnap.data();
      const email = String(userData?.email || "").trim();
      if (!email) continue;

      const searchesQ = await db
        .collection(COLLECTIONS.savedSearches)
        .where("user_id", "==", userId)
        .limit(50)
        .get();
      if (searchesQ.empty) continue;

      let matchCount = 0;
      for (const s of searchesQ.docs) {
        const data = s.data();
        matchCount += Number(data.last_match_count || data.match_count || 0);
      }

      const capped = capDigestMatchCount(matchCount);
      if (capped.capped) cappedUsers += 1;

      const bucketKey = mode === "daily" ? localDayKey(parts) : localWeekKey(parts);
      const eventName = mode === "daily" ? "saved_search.daily_digest.ready" : "saved_search.weekly_digest.ready";
      const eventId = `evt_saved_search_${mode}_digest_${userId}_${bucketKey}`;

      pendingEvents.push({
        eventId,
        payload: {
          event_id: eventId,
          event_name: eventName,
          source_collection: COLLECTIONS.savedSearches,
          source_id: userId,
          recipient_user_id: userId,
          dedupe_key: sha256(`${eventName}:${userId}:${bucketKey}`),
          occurred_at: now,
          payload: {
            recipient_email: email,
            searchName: "Vos alertes PRESTO",
            matchCount: capped.matchCount,
            rawMatchCount: capped.rawMatchCount,
            matchCountCapped: capped.capped,
            resultsUrl: "https://presto.app/recherche-sauvegardee",
            digestMode: mode,
            timezone,
            bucketKey,
            catchupEmission: window.catchup,
          },
          status: "created",
        },
      });

      if (window.catchup) emittedCatchup += 1;
      if (emitted >= DIGEST_MAX_EVENTS_PER_RUN) break;
    }

    for (let i = 0; i < pendingEvents.length; i += DIGEST_BATCH_WRITE_SIZE) {
      const chunk = pendingEvents.slice(i, i + DIGEST_BATCH_WRITE_SIZE);
      await Promise.all(
        chunk.map(async (e) => {
          try {
            await db.collection(COLLECTIONS.emailEvents).doc(e.eventId).create(e.payload);
            emitted += 1;
          } catch (err) {
            const msg = String(err);
            if (msg.includes("ALREADY_EXISTS") || msg.includes("already exists")) {
              skippedAlreadyExists += 1;
              return;
            }
            throw err;
          }
        }),
      );
      if (emitted >= DIGEST_MAX_EVENTS_PER_RUN) break;
    }

    if (prefsQ.docs.length < DIGEST_PAGE_SIZE) {
      lastDocId = "";
      break;
    }
  }

  await cursorRef.set(
    {
      notification_pref_cursor: lastDocId,
      updated_at: now,
      last_run_stats: {
        scanned,
        emitted,
        pages,
        emitted_catchup: emittedCatchup,
        capped_users: cappedUsers,
        skipped_already_exists: skippedAlreadyExists,
      },
    },
    { merge: true },
  );

  await db.collection(COLLECTIONS.audits).add({
    action: "digest.scheduler.tick",
    created_at: now,
    emitted_events: emitted,
    scanned_prefs: scanned,
    pages,
    emitted_catchup: emittedCatchup,
    capped_users: cappedUsers,
    skipped_already_exists: skippedAlreadyExists,
    cursor_after: lastDocId || null,
  });
});

export const retryFailedEmailJobs = onSchedule("every 30 minutes", async () => {
  const now = Date.now();
  const q = await db
    .collection(COLLECTIONS.emailJobs)
    .where("status", "==", "scheduled")
    .where("send_at", "<=", now)
    .limit(100)
    .get();

  for (const doc of q.docs) {
    await processSingleJob(doc.id);
  }
});

export const cleanupExpiredEmailJobs = onSchedule("every day 03:15", async () => {
  const now = Date.now();
  const q = await db
    .collection(COLLECTIONS.emailJobs)
    .where("expires_at", "<", now)
    .where("status", "in", ["queued", "scheduled"])
    .limit(300)
    .get();

  for (const doc of q.docs) {
    await doc.ref.set({ status: "cancelled", updated_at: now }, { merge: true });
  }
});
