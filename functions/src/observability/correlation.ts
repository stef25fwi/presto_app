import { randomUUID } from "node:crypto";

const CORRELATION_ID_PATTERN = /^[A-Za-z0-9._:-]{8,80}$/;

export function normalizeCorrelationId(value: unknown): string | null {
  const normalized = String(value ?? "").trim();
  if (!CORRELATION_ID_PATTERN.test(normalized)) return null;
  return normalized;
}

export function resolveCorrelationId(value: unknown): string {
  return normalizeCorrelationId(value) ?? randomUUID();
}

export function buildOperationLogContext({
  correlationId,
  operation,
  actorId,
}: {
  correlationId: string;
  operation: string;
  actorId?: string;
}): Record<string, string> {
  const normalizedOperation = String(operation).trim();
  if (!normalizedOperation) {
    throw new Error("operation is required");
  }

  const context: Record<string, string> = {
    correlationId: resolveCorrelationId(correlationId),
    operation: normalizedOperation,
  };
  const normalizedActorId = String(actorId ?? "").trim();
  if (normalizedActorId) context.actorId = normalizedActorId;
  return context;
}
