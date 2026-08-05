import admin from "../../../core/firebase_admin_compat";
import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import type { ProductAnalyticsEvent } from "../constants/enums";

function sanitizeParams(params: Record<string, unknown>): Record<string, string | number | boolean | null> {
  const result: Record<string, string | number | boolean | null> = {};
  for (const [key, value] of Object.entries(params)) {
    if (value == null) {
      result[key] = null;
      continue;
    }
    if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
      result[key] = value;
      continue;
    }
    result[key] = String(value);
  }
  return result;
}

function dateKeyFromDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export async function trackProductEventBackend({
  eventName,
  userId,
  listingId,
  threadId,
  params = {},
}: {
  eventName: ProductAnalyticsEvent;
  userId?: string;
  listingId?: string;
  threadId?: string;
  params?: Record<string, unknown>;
}): Promise<void> {
  const sanitizedParams = sanitizeParams(params);
  logger.info("marketplace_product_event", {
    eventName,
    userId,
    listingId,
    threadId,
    ...sanitizedParams,
  });

  const now = new Date();
  const dateKey = dateKeyFromDate(now);
  const snapshotId = `${dateKey}_marketplace`;
  await db.collection(COLLECTIONS.analyticsSnapshots).doc(snapshotId).set({
    id: snapshotId,
    dateKey,
    metricGroup: "marketplace",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    [`metrics.${eventName}`]: admin.firestore.FieldValue.increment(1),
  }, { merge: true });
}