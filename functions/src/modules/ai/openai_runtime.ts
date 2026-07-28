import OpenAI from "openai";

import { OPENAI_API_KEY } from "../../config/env";
import { logger } from "../../core/logger";

const DEFAULT_TIMEOUT_MS = 25_000;
const DEFAULT_MAX_RETRIES = 1;

let singletonClient: OpenAI | null = null;
let singletonApiKey = "";

export interface OpenAiErrorInfo {
  status: number | null;
  code: string | null;
  type: string | null;
  requestId: string | null;
  name: string;
  message: string;
  retryable: boolean;
  timeout: boolean;
  quotaExhausted: boolean;
}

export interface OpenAiOperationLog {
  operation: string;
  requestId: string;
  model: string;
  promptVersion?: string;
  schemaVersion?: string;
  startedAtMs: number;
  cacheHit?: boolean;
}

function optionalString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized || null;
}

function optionalNumber(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function getOpenAiClient(): OpenAI {
  const apiKey = OPENAI_API_KEY.value().trim();
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY_NOT_CONFIGURED");
  }

  if (singletonClient && singletonApiKey === apiKey) {
    return singletonClient;
  }

  singletonApiKey = apiKey;
  singletonClient = new OpenAI({
    apiKey,
    timeout: DEFAULT_TIMEOUT_MS,
    maxRetries: DEFAULT_MAX_RETRIES,
  });
  return singletonClient;
}

export function classifyOpenAiError(error: unknown): OpenAiErrorInfo {
  const value = error as Record<string, unknown> | null;
  const status = optionalNumber(value?.status);
  const code = optionalString(value?.code);
  const type = optionalString(value?.type);
  const requestId =
    optionalString(value?.request_id) ||
    optionalString(value?._request_id) ||
    optionalString((value?.headers as Record<string, unknown> | undefined)?.["x-request-id"]);
  const name = optionalString(value?.name) || "Error";
  const message = optionalString(value?.message) || String(error);
  const normalizedMessage = message.toLowerCase();
  const normalizedCode = (code || "").toLowerCase();
  const timeout =
    name.includes("Timeout") ||
    normalizedCode.includes("timeout") ||
    normalizedMessage.includes("timeout") ||
    normalizedMessage.includes("timed out");
  const quotaExhausted =
    status === 429 &&
    (normalizedCode.includes("insufficient_quota") ||
      normalizedMessage.includes("insufficient quota") ||
      normalizedMessage.includes("billing") ||
      normalizedMessage.includes("credit"));
  const retryable =
    timeout ||
    status === 408 ||
    status === 409 ||
    (status === 429 && !quotaExhausted) ||
    (status != null && status >= 500) ||
    name.includes("APIConnectionError");

  return {
    status,
    code,
    type,
    requestId,
    name,
    message,
    retryable,
    timeout,
    quotaExhausted,
  };
}

export function logOpenAiSuccess(
  context: OpenAiOperationLog,
  response: {
    _request_id?: string | null;
    usage?: {
      prompt_tokens?: number;
      completion_tokens?: number;
      total_tokens?: number;
      prompt_tokens_details?: { cached_tokens?: number } | null;
    } | null;
  },
): void {
  const usage = response.usage || null;
  logger.info("openai.operation.success", {
    operation: context.operation,
    requestId: context.requestId,
    openAiRequestId: response._request_id || null,
    model: context.model,
    promptVersion: context.promptVersion || null,
    schemaVersion: context.schemaVersion || null,
    durationMs: Date.now() - context.startedAtMs,
    cacheHit: context.cacheHit === true,
    inputTokens: usage?.prompt_tokens ?? null,
    cachedInputTokens: usage?.prompt_tokens_details?.cached_tokens ?? null,
    outputTokens: usage?.completion_tokens ?? null,
    totalTokens: usage?.total_tokens ?? null,
  });
}

export function logOpenAiFailure(
  context: OpenAiOperationLog,
  error: unknown,
): OpenAiErrorInfo {
  const info = classifyOpenAiError(error);
  logger.error("openai.operation.failure", {
    operation: context.operation,
    requestId: context.requestId,
    openAiRequestId: info.requestId,
    model: context.model,
    promptVersion: context.promptVersion || null,
    schemaVersion: context.schemaVersion || null,
    durationMs: Date.now() - context.startedAtMs,
    status: info.status,
    code: info.code,
    type: info.type,
    errorName: info.name,
    retryable: info.retryable,
    timeout: info.timeout,
    quotaExhausted: info.quotaExhausted,
  });
  return info;
}
