import { HttpsError, onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { canProceedRateLimited } from "../../core/rate_limit";

const ALLOWED_LEVELS = new Set(["info", "warning", "error", "critical"]);
const MAX_DATA_KEYS = 20;

function boundedString(value: unknown, maxLength: number): string {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function sanitizeData(value: unknown): Record<string, string | number | boolean | null> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};

  const blockedFragments = [
    "password",
    "token",
    "secret",
    "authorization",
    "apikey",
    "card",
    "iban",
  ];
  const result: Record<string, string | number | boolean | null> = {};

  for (const [rawKey, rawValue] of Object.entries(value).slice(0, MAX_DATA_KEYS)) {
    const key = boundedString(rawKey, 80);
    if (!key) continue;
    if (blockedFragments.some((fragment) => key.toLowerCase().includes(fragment))) {
      result[key] = "[redacted]";
      continue;
    }

    if (rawValue == null || typeof rawValue === "number" || typeof rawValue === "boolean") {
      result[key] = rawValue as number | boolean | null;
    } else {
      result[key] = boundedString(rawValue, 800);
    }
  }

  return result;
}

export const reportClientMonitoringEvent = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
  },
  async (request) => {
    const uid = String(request.auth?.uid || "anonymous").trim() || "anonymous";
    const ip = boundedString(request.rawRequest.ip, 80) || "unknown";
    const rateKey = uid === "anonymous" ? `ip:${ip}` : `uid:${uid}`;
    const allowed = await canProceedRateLimited("client_monitoring", rateKey, 30, 60_000);
    if (!allowed) {
      throw new HttpsError("resource-exhausted", "monitoring rate limit exceeded");
    }

    const levelCandidate = boundedString(request.data?.level, 16).toLowerCase();
    const level = ALLOWED_LEVELS.has(levelCandidate) ? levelCandidate : "info";
    const scope = boundedString(request.data?.scope, 80);
    const action = boundedString(request.data?.action, 120);
    if (!scope || !action) {
      throw new HttpsError("invalid-argument", "scope and action are required");
    }

    await db.collection("app_monitoring_events").add({
      createdAt: FieldValue.serverTimestamp(),
      createdAtClient: boundedString(request.data?.createdAtClient, 64) || null,
      level,
      scope,
      action,
      message: boundedString(request.data?.message, 800) || null,
      userId: uid,
      platform: boundedString(request.data?.platform, 40) || "unknown",
      releaseMode: request.data?.releaseMode === true,
      appBuild: boundedString(request.data?.appBuild, 80) || "unknown",
      gitCommit: boundedString(request.data?.gitCommit, 80) || "unknown",
      buildTime: boundedString(request.data?.buildTime, 80) || "unknown",
      data: sanitizeData(request.data?.data),
    });

    return { ok: true };
  },
);
