import * as logger from "firebase-functions/logger";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export type MonitoringLevel = "info" | "warning" | "error" | "critical";

export async function monitorServerEvent(params: {
  level: MonitoringLevel;
  scope: string;
  action: string;
  message?: string;
  userId?: string;
  data?: Record<string, unknown>;
}) {
  const payload = {
    createdAt: FieldValue.serverTimestamp(),
    createdAtClient: new Date().toISOString(),
    level: params.level,
    scope: params.scope,
    action: params.action,
    message: params.message ?? null,
    userId: params.userId ?? "server",
    platform: "firebase_functions",
    data: cleanData(params.data ?? {}),
  };

  if (params.level === "error" || params.level === "critical") {
    logger.error(`[MONITORING][${params.scope}][${params.action}]`, payload);
  } else if (params.level === "warning") {
    logger.warn(`[MONITORING][${params.scope}][${params.action}]`, payload);
  } else {
    logger.info(`[MONITORING][${params.scope}][${params.action}]`, payload);
  }

  await getFirestore().collection("app_monitoring_events").add(payload);
}

function cleanData(data: Record<string, unknown>): Record<string, unknown> {
  const blocked = [
    "password",
    "token",
    "secret",
    "authorization",
    "stripeSecret",
    "apiKey",
    "card",
    "iban",
  ];

  const out: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(data)) {
    const lower = key.toLowerCase();

    if (blocked.some((blockedKey) => lower.includes(blockedKey))) {
      out[key] = "[redacted]";
      continue;
    }

    const text = typeof value === "string" ? value : JSON.stringify(value);

    out[key] = text && text.length > 800
      ? `${text.substring(0, 800)}...[truncated]`
      : value;
  }

  return out;
}
