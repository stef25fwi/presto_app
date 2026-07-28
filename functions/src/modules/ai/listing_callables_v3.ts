import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  ENFORCE_APP_CHECK,
  OPENAI_API_KEY,
  PROJECT_REGION,
} from "../../config/env";
import { runIdempotentOperation } from "./idempotency";
import {
  assertAuthenticated,
  buildLegacyDraftPayload,
  buildTranscriptionPayload,
  cleanString,
  enforceRateLimit,
  generateStructuredListing,
  PIPELINE_VERSION,
  prepareAudioInput,
  requestIdFrom,
  transcribeWithOpenAi,
} from "./listing_pipeline";
import { scheduleAudioCleanup } from "./operational_cleanup";

export const generateOfferDraft = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 45,
    memory: "256MiB",
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = assertAuthenticated(request);
    await enforceRateLimit(uid, "generate_offer_draft", 15, 60);
    const input = cleanString(request.data?.hint ?? request.data?.input) || "";
    const city = cleanString(request.data?.city) || "";
    const category = cleanString(request.data?.category) || "";
    const languageCode = cleanString(request.data?.lang) || "fr";
    if (!input) throw new HttpsError("invalid-argument", "INPUT_REQUIRED");
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      input,
      city,
      category,
      languageCode,
      PIPELINE_VERSION,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "generate_offer_draft_v3",
      requestId,
      execute: async () => {
        const result = await generateStructuredListing({
          input,
          city,
          category,
          languageCode,
          requestId,
          operation: "generate_offer_draft",
          draftMode: true,
        });
        return buildLegacyDraftPayload(result);
      },
    });
    return {
      ...operation.value,
      pipelineVersion: PIPELINE_VERSION,
      cacheHit: operation.cacheHit,
    };
  },
);

export const openAiExtractListingFields = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 45,
    memory: "256MiB",
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = assertAuthenticated(request);
    await enforceRateLimit(uid, "openai_extract_listing_fields", 15, 60);
    const input = cleanString(request.data?.input ?? request.data?.hint) || "";
    const city = cleanString(request.data?.city) || "";
    const category = cleanString(request.data?.category) || "";
    const languageCode = cleanString(request.data?.languageCode) || "fr-FR";
    if (!input) throw new HttpsError("invalid-argument", "INPUT_REQUIRED");
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      input,
      city,
      category,
      languageCode,
      PIPELINE_VERSION,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "extract_listing_fields_v3",
      requestId,
      execute: async () => ({
        result: await generateStructuredListing({
          input,
          city,
          category,
          languageCode,
          requestId,
          operation: "extract_listing_fields",
          draftMode: false,
        }),
      }),
    });
    return {
      ...operation.value,
      pipelineVersion: PIPELINE_VERSION,
      cacheHit: operation.cacheHit,
    };
  },
);

export const openAiTranscribeListingAudio = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 90,
    memory: "512MiB",
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = assertAuthenticated(request);
    await enforceRateLimit(uid, "openai_transcribe_listing_audio", 20, 60);
    const storagePath = cleanString(request.data?.storagePath) || "";
    const inlineBase64 = cleanString(request.data?.audioBase64) || "";
    const languageCode = cleanString(request.data?.languageCode) || "fr-FR";
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      storagePath,
      inlineBase64,
      languageCode,
      PIPELINE_VERSION,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "transcribe_listing_audio_v3",
      requestId,
      execute: async () => {
        const audio = await prepareAudioInput({
          uid,
          storagePath,
          audioBase64: inlineBase64,
          audioContentType: request.data?.audioContentType,
        });
        const transcription = await transcribeWithOpenAi({
          audio,
          languageCode,
          requestId,
          operation: "transcribe_listing_audio",
        });
        if (audio.fromStorage) {
          await scheduleAudioCleanup({ uid, storagePath: audio.storagePath, requestId });
        }
        return {
          transcription: buildTranscriptionPayload({
            ...transcription,
            languageCode,
            storagePath: audio.storagePath,
            durationSeconds: audio.durationSeconds,
          }),
        };
      },
    });
    return {
      ...operation.value,
      pipelineVersion: PIPELINE_VERSION,
      cacheHit: operation.cacheHit,
    };
  },
);

export const openAiExtractListingFieldsFromAudio = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    secrets: [OPENAI_API_KEY],
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = assertAuthenticated(request);
    await enforceRateLimit(uid, "openai_extract_listing_fields_from_audio", 10, 60);
    const storagePath = cleanString(request.data?.storagePath) || "";
    const inlineBase64 = cleanString(request.data?.audioBase64) || "";
    const city = cleanString(request.data?.city) || "";
    const category = cleanString(request.data?.category) || "";
    const languageCode = cleanString(request.data?.languageCode) || "fr-FR";
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      storagePath,
      inlineBase64,
      city,
      category,
      languageCode,
      PIPELINE_VERSION,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "extract_listing_fields_from_audio_v3",
      requestId,
      execute: async () => {
        const audio = await prepareAudioInput({
          uid,
          storagePath,
          audioBase64: inlineBase64,
          audioContentType: request.data?.audioContentType,
        });
        const transcription = await transcribeWithOpenAi({
          audio,
          languageCode,
          requestId,
          operation: "extract_listing_audio_transcription",
        });
        const result = await generateStructuredListing({
          input: transcription.text,
          city,
          category,
          languageCode,
          requestId,
          operation: "extract_listing_audio_fields",
          draftMode: false,
        });
        if (audio.fromStorage) {
          await scheduleAudioCleanup({ uid, storagePath: audio.storagePath, requestId });
        }
        return {
          result,
          transcription: buildTranscriptionPayload({
            ...transcription,
            languageCode,
            storagePath: audio.storagePath,
            durationSeconds: audio.durationSeconds,
          }),
        };
      },
    });
    return {
      ...operation.value,
      pipelineVersion: PIPELINE_VERSION,
      cacheHit: operation.cacheHit,
    };
  },
);
