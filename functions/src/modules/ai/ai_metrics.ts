import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { logger } from "../../core/logger";
import {
  latencyBucketField,
  latencyPercentiles,
  mergeLatencyBuckets,
} from "./latency_histogram";
import {
  extractRolesFromAuthToken,
  requireAnyRole,
} from "../marketplace/services/roles";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const COLLECTION = "_ai_metrics_daily";

export interface AiMetricInput {
  operation: string;
  provider: "openai" | "google" | "cache" | "system";
  model: string;
  success: boolean;
  durationMs: number;
  inputTokens?: number | null;
  outputTokens?: number | null;
  cachedInputTokens?: number | null;
  audioSeconds?: number | null;
  fallbackUsed?: boolean;
  cacheHit?: boolean;
  errorCode?: string | null;
  pipelineVersion?: string;
}

interface AiMetricRow extends Record<string, unknown> {
  id: string;
  count?: number;
  successCount?: number;
  failureCount?: number;
  fallbackCount?: number;
  cacheHitCount?: number;
  totalDurationMs?: number;
  estimatedCostMicrosEur?: number;
}

function safeSegment(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_.-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 80) || "unknown";
}

function dayKey(date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

function numericEnv(name: string): number {
  const parsed = Number(process.env[name] || 0);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

export function estimateAiCostMicrosEur(input: AiMetricInput): number {
  const inputRate = numericEnv("OPENAI_INPUT_EUR_PER_MILLION_TOKENS");
  const cachedRate = numericEnv("OPENAI_CACHED_INPUT_EUR_PER_MILLION_TOKENS");
  const outputRate = numericEnv("OPENAI_OUTPUT_EUR_PER_MILLION_TOKENS");
  const transcriptionRate = numericEnv("OPENAI_TRANSCRIPTION_EUR_PER_MINUTE");
  const inputTokens = Math.max(0, Number(input.inputTokens || 0));
  const cachedTokens = Math.min(
    inputTokens,
    Math.max(0, Number(input.cachedInputTokens || 0)),
  );
  const uncachedTokens = inputTokens - cachedTokens;
  const outputTokens = Math.max(0, Number(input.outputTokens || 0));
  const audioMinutes = Math.max(0, Number(input.audioSeconds || 0)) / 60;
  const costEur =
    (uncachedTokens / 1_000_000) * inputRate +
    (cachedTokens / 1_000_000) * cachedRate +
    (outputTokens / 1_000_000) * outputRate +
    audioMinutes * transcriptionRate;
  return Math.max(0, Math.round(costEur * 1_000_000));
}

export async function recordAiMetric(input: AiMetricInput): Promise<void> {
  const normalized: AiMetricInput = {
    ...input,
    operation: safeSegment(input.operation),
    model: safeSegment(input.model),
    pipelineVersion: safeSegment(input.pipelineVersion || "unknown"),
    durationMs: Math.max(0, Math.round(input.durationMs || 0)),
  };
  const id = [
    dayKey(),
    safeSegment(normalized.operation),
    safeSegment(normalized.provider),
    safeSegment(normalized.model),
    safeSegment(normalized.pipelineVersion || "unknown"),
  ].join("__");
  const ref = admin.firestore().collection(COLLECTION).doc(id);
  const costMicrosEur = estimateAiCostMicrosEur(normalized);
  const bucketField = latencyBucketField(normalized.durationMs);
  const increments: Record<string, unknown> = {
    day: dayKey(),
    operation: normalized.operation,
    provider: normalized.provider,
    model: normalized.model,
    pipelineVersion: normalized.pipelineVersion || "unknown",
    count: admin.firestore.FieldValue.increment(1),
    successCount: admin.firestore.FieldValue.increment(normalized.success ? 1 : 0),
    failureCount: admin.firestore.FieldValue.increment(normalized.success ? 0 : 1),
    fallbackCount: admin.firestore.FieldValue.increment(normalized.fallbackUsed ? 1 : 0),
    cacheHitCount: admin.firestore.FieldValue.increment(normalized.cacheHit ? 1 : 0),
    totalDurationMs: admin.firestore.FieldValue.increment(normalized.durationMs),
    [bucketField]: admin.firestore.FieldValue.increment(1),
    totalInputTokens: admin.firestore.FieldValue.increment(
      Math.max(0, Number(normalized.inputTokens || 0)),
    ),
    totalCachedInputTokens: admin.firestore.FieldValue.increment(
      Math.max(0, Number(normalized.cachedInputTokens || 0)),
    ),
    totalOutputTokens: admin.firestore.FieldValue.increment(
      Math.max(0, Number(normalized.outputTokens || 0)),
    ),
    totalAudioSeconds: admin.firestore.FieldValue.increment(
      Math.max(0, Number(normalized.audioSeconds || 0)),
    ),
    estimatedCostMicrosEur: admin.firestore.FieldValue.increment(costMicrosEur),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(
      Date.now() + 120 * 24 * 60 * 60 * 1000,
    ),
  };
  if (normalized.errorCode) {
    increments.lastErrorCode = safeSegment(normalized.errorCode);
  }
  await ref.set(increments, { merge: true }).catch((error) => {
    logger.warn("ai.metrics.write_failed", {
      operation: normalized.operation,
      model: normalized.model,
      errorName: error instanceof Error ? error.name : "Error",
    });
  });
}

export const adminGetAiMetrics = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 20,
    memory: "256MiB",
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
    }
    const roles = extractRolesFromAuthToken(request.auth?.token || {});
    requireAnyRole(roles, ["admin", "superadmin"], "Admin access required");
    const requestedDays = Number(request.data?.days || 14);
    const days = Math.min(90, Math.max(1, Math.round(requestedDays)));
    const start = new Date(Date.now() - (days - 1) * 24 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
    const snapshot = await admin
      .firestore()
      .collection(COLLECTION)
      .where("day", ">=", start)
      .orderBy("day", "desc")
      .limit(500)
      .get();
    const rows: AiMetricRow[] = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...(doc.data() as Record<string, unknown>),
    }));
    const totals = rows.reduce(
      (acc, row) => {
        acc.count += Number(row.count || 0);
        acc.successCount += Number(row.successCount || 0);
        acc.failureCount += Number(row.failureCount || 0);
        acc.fallbackCount += Number(row.fallbackCount || 0);
        acc.cacheHitCount += Number(row.cacheHitCount || 0);
        acc.totalDurationMs += Number(row.totalDurationMs || 0);
        acc.estimatedCostMicrosEur += Number(row.estimatedCostMicrosEur || 0);
        return acc;
      },
      {
        count: 0,
        successCount: 0,
        failureCount: 0,
        fallbackCount: 0,
        cacheHitCount: 0,
        totalDurationMs: 0,
        estimatedCostMicrosEur: 0,
      },
    );
    const latencyBuckets = mergeLatencyBuckets(rows);
    const percentiles = latencyPercentiles(rows);
    return {
      days,
      rows,
      totals: {
        ...totals,
        successRate: totals.count > 0 ? totals.successCount / totals.count : null,
        averageDurationMs:
          totals.count > 0 ? Math.round(totals.totalDurationMs / totals.count) : null,
        estimatedCostEur: totals.estimatedCostMicrosEur / 1_000_000,
        latencyBuckets,
        latencyMs: percentiles,
      },
    };
  },
);
