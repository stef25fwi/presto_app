import crypto from "node:crypto";

import { HttpsError } from "firebase-functions/v2/https";

import { logger } from "../../core/logger";
import {
  classifyOpenAiError,
  getOpenAiClient,
} from "./openai_runtime";

export interface TtsConfig {
  model: string;
  voice: string;
  responseFormat: "mp3";
}

export function resolveTtsConfig(requestedVoice?: unknown): TtsConfig {
  const voice =
    typeof requestedVoice === "string" && requestedVoice.trim()
      ? requestedVoice.trim()
      : process.env.OPENAI_TTS_VOICE?.trim() || "alloy";
  return {
    model: process.env.OPENAI_TTS_MODEL?.trim() || "tts-1",
    voice,
    responseFormat: "mp3",
  };
}

export function buildTtsTextHash(text: string, config: TtsConfig): string {
  return crypto
    .createHash("sha256")
    .update(`${config.model}|${config.voice}|${config.responseFormat}|${text}`)
    .digest("hex");
}

function mapTtsError(error: unknown): HttpsError {
  const info = classifyOpenAiError(error);
  logger.error("openai.tts.failure", {
    openAiRequestId: info.requestId,
    status: info.status,
    code: info.code,
    timeout: info.timeout,
    retryable: info.retryable,
    quotaExhausted: info.quotaExhausted,
  });
  if (info.timeout) {
    return new HttpsError("deadline-exceeded", "AI_TIMEOUT", { retryable: true });
  }
  if (info.status === 429) {
    return new HttpsError(
      "resource-exhausted",
      info.quotaExhausted ? "AI_QUOTA_EXHAUSTED" : "AI_RATE_LIMITED",
      { retryable: !info.quotaExhausted },
    );
  }
  if (info.retryable) {
    return new HttpsError("unavailable", "AI_PROVIDER_UNAVAILABLE", {
      retryable: true,
    });
  }
  return new HttpsError("internal", "AI_TTS_FAILED", { retryable: false });
}

export async function generateTtsMp3(options: {
  text: string;
  config: TtsConfig;
}): Promise<{ buffer: Buffer; openAiRequestId: string | null; durationMs: number }> {
  const startedAtMs = Date.now();
  try {
    const response = await getOpenAiClient().audio.speech.create(
      {
        model: options.config.model,
        voice: options.config.voice as never,
        input: options.text,
        response_format: options.config.responseFormat,
      },
      { timeout: 45_000, maxRetries: 1 },
    );
    const buffer = Buffer.from(await response.arrayBuffer());
    if (!buffer.length) {
      throw new HttpsError("internal", "AI_TTS_EMPTY", { retryable: false });
    }
    const openAiRequestId =
      (response as unknown as { _request_id?: string | null })._request_id || null;
    const durationMs = Date.now() - startedAtMs;
    logger.info("openai.tts.success", {
      openAiRequestId,
      model: options.config.model,
      voice: options.config.voice,
      durationMs,
      sizeBytes: buffer.length,
    });
    return { buffer, openAiRequestId, durationMs };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw mapTtsError(error);
  }
}
