import crypto from "node:crypto";

import admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

import { logger } from "../../core/logger";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const COLLECTION = "_ai_idempotency";
const IN_FLIGHT_MAX_AGE_MS = 2 * 60 * 1000;
const DEFAULT_TTL_MS = 24 * 60 * 60 * 1000;

interface StoredOperation<T> {
  status?: "processing" | "completed" | "failed";
  startedAtMs?: number;
  completedAtMs?: number;
  result?: T;
  retryable?: boolean;
}

export interface IdempotentOperationResult<T> {
  value: T;
  cacheHit: boolean;
  documentId: string;
}

export interface IdempotentOperationOptions<T extends Record<string, unknown>> {
  uid: string;
  operation: string;
  requestId: string;
  execute: () => Promise<T>;
  ttlMs?: number;
}

export function normalizeClientRequestId(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim().replace(/[^a-zA-Z0-9_.:-]/g, "_").slice(0, 180);
}

export function deriveClientRequestId(parts: readonly unknown[]): string {
  const normalized = parts.map((part) => String(part ?? "").trim()).join("|");
  return crypto.createHash("sha256").update(normalized).digest("hex").slice(0, 40);
}

export function buildIdempotencyDocumentId(
  uid: string,
  operation: string,
  requestId: string,
): string {
  return crypto
    .createHash("sha256")
    .update(`${uid}|${operation}|${requestId}`)
    .digest("hex");
}

function isRetryableFailure(error: unknown): boolean {
  if (error instanceof HttpsError) {
    return (
      error.code === "aborted" ||
      error.code === "deadline-exceeded" ||
      error.code === "resource-exhausted" ||
      error.code === "unavailable"
    );
  }
  return false;
}

export async function runIdempotentOperation<T extends Record<string, unknown>>(
  options: IdempotentOperationOptions<T>,
): Promise<IdempotentOperationResult<T>> {
  const normalizedRequestId = normalizeClientRequestId(options.requestId);
  if (!normalizedRequestId) {
    return {
      value: await options.execute(),
      cacheHit: false,
      documentId: "",
    };
  }

  const now = Date.now();
  const ttlMs = Math.max(60_000, options.ttlMs ?? DEFAULT_TTL_MS);
  const documentId = buildIdempotencyDocumentId(
    options.uid,
    options.operation,
    normalizedRequestId,
  );
  const ref = admin.firestore().collection(COLLECTION).doc(documentId);

  const cached = await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const stored = snapshot.exists
      ? (snapshot.data() as StoredOperation<T>)
      : null;

    if (stored?.status === "completed" && stored.result) {
      return stored.result;
    }

    if (
      stored?.status === "processing" &&
      typeof stored.startedAtMs === "number" &&
      now - stored.startedAtMs < IN_FLIGHT_MAX_AGE_MS
    ) {
      throw new HttpsError(
        "aborted",
        "AI_REQUEST_IN_PROGRESS",
        { retryable: true, requestId: normalizedRequestId },
      );
    }

    transaction.set(
      ref,
      {
        uid: options.uid,
        operation: options.operation,
        requestId: normalizedRequestId,
        status: "processing",
        startedAtMs: now,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(now + ttlMs),
      },
      { merge: true },
    );
    return null;
  });

  if (cached) {
    logger.info("ai.idempotency.hit", {
      operation: options.operation,
      uid: options.uid,
      documentId,
    });
    return { value: cached, cacheHit: true, documentId };
  }

  try {
    const value = await options.execute();
    await ref.set(
      {
        status: "completed",
        result: value,
        completedAtMs: Date.now(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + ttlMs),
      },
      { merge: true },
    );
    return { value, cacheHit: false, documentId };
  } catch (error) {
    await ref.set(
      {
        status: "failed",
        retryable: isRetryableFailure(error),
        completedAtMs: Date.now(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + ttlMs),
      },
      { merge: true },
    ).catch(() => undefined);
    throw error;
  }
}
