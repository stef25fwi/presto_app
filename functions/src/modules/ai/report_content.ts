import admin from "../../core/firebase_admin_compat";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import {
  ENFORCE_APP_CHECK,
  PROJECT_REGION,
} from "../../config/env";
import { db } from "../../core/firestore";
import { canProceedRateLimited } from "../../core/rate_limit";
import { logger } from "../../core/logger";

const ALLOWED_SOURCES = new Set([
  "publish_text",
  "publish_voice",
  "other",
]);
const ALLOWED_REASONS = new Set([
  "offensive",
  "illegal",
  "personal_data",
  "fraud",
  "other",
]);

function normalized(value: unknown, maxLength = 160): string {
  return String(value ?? "").trim().slice(0, maxLength);
}

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = normalized(request.auth?.uid, 128);
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

export function validateAiContentReportPayload(
  data: Record<string, unknown>,
): { source: string; reasonCode: string; details: string } {
  const source = normalized(data.source, 32);
  const reasonCode = normalized(data.reasonCode, 32);
  const details = normalized(data.details, 500);

  if (!ALLOWED_SOURCES.has(source)) {
    throw new HttpsError("invalid-argument", "A valid AI content source is required");
  }
  if (!ALLOWED_REASONS.has(reasonCode)) {
    throw new HttpsError("invalid-argument", "A valid AI content report reason is required");
  }

  return { source, reasonCode, details };
}

export const reportAiGeneratedContent = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const reporterId = requireAuthUid(request);
    const rateAllowed = await canProceedRateLimited(
      "ai_content_report",
      reporterId,
      10,
      24 * 60 * 60 * 1000,
    );
    if (!rateAllowed) {
      throw new HttpsError("resource-exhausted", "Too many AI content reports today");
    }

    const payload = validateAiContentReportPayload(
      (request.data ?? {}) as Record<string, unknown>,
    );
    const reportRef = db.collection("aiContentReports").doc();

    await reportRef.set({
      id: reportRef.id,
      reporterId,
      source: payload.source,
      reasonCode: payload.reasonCode,
      details: payload.details || null,
      status: "open",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("ai_generated_content_reported", {
      reportId: reportRef.id,
      reporterId,
      source: payload.source,
      reasonCode: payload.reasonCode,
    });

    return { ok: true, reportId: reportRef.id };
  },
);
