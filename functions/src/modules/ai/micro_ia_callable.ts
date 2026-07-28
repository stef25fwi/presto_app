import { SpeechClient } from "@google-cloud/speech";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  ENFORCE_APP_CHECK,
  OPENAI_API_KEY,
  PROJECT_REGION,
} from "../../config/env";
import { logger } from "../../core/logger";
import { recordAiMetric } from "./ai_metrics";
import { runIdempotentOperation } from "./idempotency";
import {
  assertAuthenticated,
  buildLegacyDraftPayload,
  cleanString,
  enforceRateLimit,
  evaluateTranscriptQuality,
  generateStructuredListing,
  PIPELINE_VERSION,
  PreparedAudio,
  prepareAudioInput,
  requestIdFrom,
  transcribeWithOpenAi,
} from "./listing_pipeline";
import { correctAntillesTranscript } from "./listing_taxonomy";
import { scheduleAudioCleanup } from "./operational_cleanup";

let speechClient: SpeechClient | null = null;

function getSpeechClient(): SpeechClient {
  speechClient ??= new SpeechClient();
  return speechClient;
}

function googleEncoding(contentType: string): string | null {
  if (contentType.includes("webm")) return "WEBM_OPUS";
  if (contentType.includes("ogg")) return "OGG_OPUS";
  if (contentType.includes("flac")) return "FLAC";
  if (contentType.includes("mpeg") || contentType.includes("mp3")) return "MP3";
  if (contentType.includes("wav")) return "LINEAR16";
  return null;
}

function googleEligible(audio: PreparedAudio): boolean {
  return googleEncoding(audio.contentType) != null;
}

async function transcribeWithGoogle(options: {
  audio: PreparedAudio;
  languageCode: string;
  requestId: string;
}): Promise<{ text: string; confidence: number | null }> {
  const startedAtMs = Date.now();
  const encoding = googleEncoding(options.audio.contentType);
  if (!encoding) throw new HttpsError("failed-precondition", "GOOGLE_STT_UNSUPPORTED_AUDIO");
  try {
    const [response] = await getSpeechClient().recognize(
      {
        audio: { content: options.audio.buffer.toString("base64") },
        config: {
          encoding,
          languageCode: options.languageCode || "fr-FR",
          alternativeLanguageCodes: ["fr-FR", "fr-GP"],
          model: "latest_short",
          useEnhanced: true,
          enableAutomaticPunctuation: true,
          enableWordTimeOffsets: false,
          maxAlternatives: 1,
          speechContexts: [
            {
              phrases: [
                "iliprestō",
                "Baie-Mahault",
                "Les Abymes",
                "Pointe-à-Pitre",
                "Petit-Bourg",
                "Le Gosier",
                "Saint-François",
                "Fort-de-France",
                "jardinage",
                "bricolage",
                "peinture",
                "plomberie",
                "électricité",
                "déménagement",
              ],
              boost: 12,
            },
          ],
        },
      } as never,
      { timeout: 12_000 } as never,
    );
    const alternatives = (response.results || [])
      .map((result) => result.alternatives?.[0])
      .filter((item): item is NonNullable<typeof item> => item != null);
    const text = correctAntillesTranscript(
      alternatives.map((item) => item.transcript || "").join(" "),
    );
    const confidenceValues = alternatives
      .map((item) => Number(item.confidence))
      .filter((value) => Number.isFinite(value) && value > 0);
    const confidence = confidenceValues.length
      ? confidenceValues.reduce((sum, value) => sum + value, 0) /
        confidenceValues.length
      : null;
    await recordAiMetric({
      operation: "micro_ia_google_stt",
      provider: "google",
      model: "latest_short",
      success: Boolean(text),
      durationMs: Date.now() - startedAtMs,
      audioSeconds: options.audio.durationSeconds,
      pipelineVersion: PIPELINE_VERSION,
    });
    if (!text) throw new HttpsError("failed-precondition", "AUDIO_TRANSCRIPT_EMPTY");
    return { text, confidence };
  } catch (error) {
    await recordAiMetric({
      operation: "micro_ia_google_stt",
      provider: "google",
      model: "latest_short",
      success: false,
      durationMs: Date.now() - startedAtMs,
      audioSeconds: options.audio.durationSeconds,
      errorCode: error instanceof Error ? error.message : "unknown",
      pipelineVersion: PIPELINE_VERSION,
    });
    throw error;
  }
}

function qualityThreshold(): number {
  const parsed = Number(process.env.MICRO_IA_GOOGLE_QUALITY_THRESHOLD || 0.62);
  return Number.isFinite(parsed) ? Math.max(0.3, Math.min(0.9, parsed)) : 0.62;
}

function mapPipelineError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  const value = error as { code?: unknown; message?: unknown } | null;
  const code = String(value?.code || "").toLowerCase();
  const message = String(value?.message || "").toLowerCase();
  if (code.includes("deadline") || code === "4" || message.includes("deadline")) {
    return new HttpsError("deadline-exceeded", "AI_TIMEOUT", { retryable: true });
  }
  if (code === "8" || message.includes("resource exhausted")) {
    return new HttpsError("resource-exhausted", "AI_RATE_LIMITED", {
      retryable: true,
    });
  }
  if (code === "14" || message.includes("unavailable")) {
    return new HttpsError("unavailable", "AI_PROVIDER_UNAVAILABLE", {
      retryable: true,
    });
  }
  return new HttpsError("internal", "AI_PIPELINE_FAILED", {
    retryable: false,
  });
}

export const microIaProcessAudioV2 = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 90,
    minInstances: 1,
    memory: "512MiB",
    cpu: 1,
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    const totalStartedAtMs = Date.now();
    const uid = assertAuthenticated(request);
    const storagePath = cleanString(request.data?.storagePath) || "";
    const audioBase64 = cleanString(request.data?.audioBase64) || "";
    const audioContentType = cleanString(request.data?.audioContentType) || "";
    const languageCode = cleanString(request.data?.languageCode) || "fr-FR";
    const generateDraft = request.data?.generateDraft === true;
    const city = cleanString(request.data?.draftCity) || "";
    const category = cleanString(request.data?.draftCategory) || "";
    if (!storagePath && !audioBase64) {
      throw new HttpsError("invalid-argument", "AUDIO_REQUIRED");
    }
    await enforceRateLimit(uid, "micro_ia_process_v2", 12, 60);
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      storagePath,
      audioBase64,
      audioContentType,
      languageCode,
      city,
      category,
      generateDraft,
      PIPELINE_VERSION,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "micro_ia_process_v2",
      requestId,
      execute: async () => {
        let audio: PreparedAudio | null = null;
        let completed = false;
        try {
          const downloadStartedAtMs = Date.now();
          audio = await prepareAudioInput({
            uid,
            storagePath,
            audioBase64,
            audioContentType,
          });
          const downloadMs = Date.now() - downloadStartedAtMs;
          const sttStartedAtMs = Date.now();
          let text = "";
          let confidence: number | null = null;
          let modeUsed = "OPENAI_TRANSCRIBE";
          let fallbackUsed = false;
          let googleQuality = null as ReturnType<typeof evaluateTranscriptQuality> | null;
          if (googleEligible(audio)) {
            try {
              const googleResult = await transcribeWithGoogle({
                audio,
                languageCode,
                requestId,
              });
              googleQuality = evaluateTranscriptQuality({
                text: googleResult.text,
                confidence: googleResult.confidence,
                threshold: qualityThreshold(),
              });
              if (googleQuality.acceptable) {
                text = googleResult.text;
                confidence = googleResult.confidence;
                modeUsed = "GOOGLE_ONLY";
              } else {
                fallbackUsed = true;
              }
            } catch (googleError) {
              fallbackUsed = true;
              logger.warn("micro_ia.google_fallback", {
                requestId,
                errorName: googleError instanceof Error ? googleError.name : "Error",
              });
            }
          } else {
            fallbackUsed = true;
          }
          if (!text) {
            const openAiResult = await transcribeWithOpenAi({
              audio,
              languageCode,
              requestId,
              operation: "micro_ia_openai_transcription",
            });
            text = openAiResult.text;
            modeUsed = "OPENAI_TRANSCRIBE";
          }
          const quality = evaluateTranscriptQuality({ text, confidence, threshold: 0.4 });
          const sttMs = Date.now() - sttStartedAtMs;
          let draft: Record<string, unknown> | null = null;
          let draftError: string | null = null;
          const draftStartedAtMs = Date.now();
          if (generateDraft && text) {
            try {
              const result = await generateStructuredListing({
                input: text,
                city,
                category,
                languageCode,
                requestId,
                operation: "micro_ia_listing_draft",
                draftMode: true,
              });
              draft = buildLegacyDraftPayload(result);
            } catch (error) {
              const mapped = mapPipelineError(error);
              draftError = mapped.message;
              logger.warn("micro_ia.draft_non_fatal", {
                requestId,
                code: mapped.code,
                message: mapped.message,
              });
            }
          }
          const draftMs = generateDraft ? Date.now() - draftStartedAtMs : 0;
          const totalMs = Date.now() - totalStartedAtMs;
          completed = true;
          await recordAiMetric({
            operation: "micro_ia_pipeline",
            provider: "system",
            model: modeUsed,
            success: true,
            durationMs: totalMs,
            audioSeconds: audio.durationSeconds,
            fallbackUsed,
            pipelineVersion: PIPELINE_VERSION,
          });
          return {
            modeUsed,
            text,
            quality,
            meta: {
              language: languageCode,
              providerConfidence: confidence,
              googleQuality,
              pipelineVersion: PIPELINE_VERSION,
              fallbackUsed,
              audioDurationSeconds: audio.durationSeconds,
            },
            draft,
            if (draftError != null) "draftError": draftError,
            timings: {
              downloadMs,
              ffmpegMs: 0,
              sttMs,
              draftMs,
              totalMs,
            },
            pipelineVersion: PIPELINE_VERSION,
          };
        } catch (error) {
          const mapped = mapPipelineError(error);
          await recordAiMetric({
            operation: "micro_ia_pipeline",
            provider: "system",
            model: "v2",
            success: false,
            durationMs: Date.now() - totalStartedAtMs,
            audioSeconds: audio?.durationSeconds,
            errorCode: mapped.message,
            pipelineVersion: PIPELINE_VERSION,
          });
          throw mapped;
        } finally {
          if (audio?.fromStorage) {
            await scheduleAudioCleanup({
              uid,
              storagePath: audio.storagePath,
              requestId,
              retentionMs: completed ? 30 * 60 * 1000 : 2 * 60 * 60 * 1000,
            }).catch(() => undefined);
          }
        }
      },
    });
    if (operation.cacheHit) {
      await recordAiMetric({
        operation: "micro_ia_pipeline",
        provider: "cache",
        model: "idempotency",
        success: true,
        durationMs: Date.now() - totalStartedAtMs,
        cacheHit: true,
        pipelineVersion: PIPELINE_VERSION,
      });
    }
    return {
      ...operation.value,
      cacheHit: operation.cacheHit,
      pipelineVersion: PIPELINE_VERSION,
    };
  },
);
