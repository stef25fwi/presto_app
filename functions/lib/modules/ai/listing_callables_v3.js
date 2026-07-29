"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.openAiExtractListingFieldsFromAudio = exports.openAiTranscribeListingAudio = exports.openAiExtractListingFields = exports.generateOfferDraft = void 0;
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const idempotency_1 = require("./idempotency");
const listing_pipeline_1 = require("./listing_pipeline");
const operational_cleanup_1 = require("./operational_cleanup");
exports.generateOfferDraft = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 45,
    memory: "256MiB",
    secrets: [env_1.OPENAI_API_KEY],
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const uid = (0, listing_pipeline_1.assertAuthenticated)(request);
    await (0, listing_pipeline_1.enforceRateLimit)(uid, "generate_offer_draft", 15, 60);
    const input = (0, listing_pipeline_1.cleanString)(request.data?.hint ?? request.data?.input) || "";
    const city = (0, listing_pipeline_1.cleanString)(request.data?.city) || "";
    const category = (0, listing_pipeline_1.cleanString)(request.data?.category) || "";
    const languageCode = (0, listing_pipeline_1.cleanString)(request.data?.lang) || "fr";
    if (!input)
        throw new https_1.HttpsError("invalid-argument", "INPUT_REQUIRED");
    const requestId = (0, listing_pipeline_1.requestIdFrom)(request.data?.clientRequestId, [
        input,
        city,
        category,
        languageCode,
        listing_pipeline_1.PIPELINE_VERSION,
    ]);
    const operation = await (0, idempotency_1.runIdempotentOperation)({
        uid,
        operation: "generate_offer_draft_v3",
        requestId,
        execute: async () => {
            const result = await (0, listing_pipeline_1.generateStructuredListing)({
                input,
                city,
                category,
                languageCode,
                requestId,
                operation: "generate_offer_draft",
                draftMode: true,
            });
            return (0, listing_pipeline_1.buildLegacyDraftPayload)(result);
        },
    });
    return {
        ...operation.value,
        pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
        cacheHit: operation.cacheHit,
    };
});
exports.openAiExtractListingFields = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 45,
    memory: "256MiB",
    secrets: [env_1.OPENAI_API_KEY],
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const uid = (0, listing_pipeline_1.assertAuthenticated)(request);
    await (0, listing_pipeline_1.enforceRateLimit)(uid, "openai_extract_listing_fields", 15, 60);
    const input = (0, listing_pipeline_1.cleanString)(request.data?.input ?? request.data?.hint) || "";
    const city = (0, listing_pipeline_1.cleanString)(request.data?.city) || "";
    const category = (0, listing_pipeline_1.cleanString)(request.data?.category) || "";
    const languageCode = (0, listing_pipeline_1.cleanString)(request.data?.languageCode) || "fr-FR";
    if (!input)
        throw new https_1.HttpsError("invalid-argument", "INPUT_REQUIRED");
    const requestId = (0, listing_pipeline_1.requestIdFrom)(request.data?.clientRequestId, [
        input,
        city,
        category,
        languageCode,
        listing_pipeline_1.PIPELINE_VERSION,
    ]);
    const operation = await (0, idempotency_1.runIdempotentOperation)({
        uid,
        operation: "extract_listing_fields_v3",
        requestId,
        execute: async () => ({
            result: await (0, listing_pipeline_1.generateStructuredListing)({
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
        pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
        cacheHit: operation.cacheHit,
    };
});
exports.openAiTranscribeListingAudio = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 90,
    memory: "512MiB",
    secrets: [env_1.OPENAI_API_KEY],
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const uid = (0, listing_pipeline_1.assertAuthenticated)(request);
    await (0, listing_pipeline_1.enforceRateLimit)(uid, "openai_transcribe_listing_audio", 20, 60);
    const storagePath = (0, listing_pipeline_1.cleanString)(request.data?.storagePath) || "";
    const inlineBase64 = (0, listing_pipeline_1.cleanString)(request.data?.audioBase64) || "";
    const languageCode = (0, listing_pipeline_1.cleanString)(request.data?.languageCode) || "fr-FR";
    const requestId = (0, listing_pipeline_1.requestIdFrom)(request.data?.clientRequestId, [
        storagePath,
        inlineBase64,
        languageCode,
        listing_pipeline_1.PIPELINE_VERSION,
    ]);
    const operation = await (0, idempotency_1.runIdempotentOperation)({
        uid,
        operation: "transcribe_listing_audio_v3",
        requestId,
        execute: async () => {
            const audio = await (0, listing_pipeline_1.prepareAudioInput)({
                uid,
                storagePath,
                audioBase64: inlineBase64,
                audioContentType: request.data?.audioContentType,
            });
            const transcription = await (0, listing_pipeline_1.transcribeWithOpenAi)({
                audio,
                languageCode,
                requestId,
                operation: "transcribe_listing_audio",
            });
            if (audio.fromStorage) {
                await (0, operational_cleanup_1.scheduleAudioCleanup)({ uid, storagePath: audio.storagePath, requestId });
            }
            return {
                transcription: (0, listing_pipeline_1.buildTranscriptionPayload)({
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
        pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
        cacheHit: operation.cacheHit,
    };
});
exports.openAiExtractListingFieldsFromAudio = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    secrets: [env_1.OPENAI_API_KEY],
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const uid = (0, listing_pipeline_1.assertAuthenticated)(request);
    await (0, listing_pipeline_1.enforceRateLimit)(uid, "openai_extract_listing_fields_from_audio", 10, 60);
    const storagePath = (0, listing_pipeline_1.cleanString)(request.data?.storagePath) || "";
    const inlineBase64 = (0, listing_pipeline_1.cleanString)(request.data?.audioBase64) || "";
    const city = (0, listing_pipeline_1.cleanString)(request.data?.city) || "";
    const category = (0, listing_pipeline_1.cleanString)(request.data?.category) || "";
    const languageCode = (0, listing_pipeline_1.cleanString)(request.data?.languageCode) || "fr-FR";
    const requestId = (0, listing_pipeline_1.requestIdFrom)(request.data?.clientRequestId, [
        storagePath,
        inlineBase64,
        city,
        category,
        languageCode,
        listing_pipeline_1.PIPELINE_VERSION,
    ]);
    const operation = await (0, idempotency_1.runIdempotentOperation)({
        uid,
        operation: "extract_listing_fields_from_audio_v3",
        requestId,
        execute: async () => {
            const audio = await (0, listing_pipeline_1.prepareAudioInput)({
                uid,
                storagePath,
                audioBase64: inlineBase64,
                audioContentType: request.data?.audioContentType,
            });
            const transcription = await (0, listing_pipeline_1.transcribeWithOpenAi)({
                audio,
                languageCode,
                requestId,
                operation: "extract_listing_audio_transcription",
            });
            const result = await (0, listing_pipeline_1.generateStructuredListing)({
                input: transcription.text,
                city,
                category,
                languageCode,
                requestId,
                operation: "extract_listing_audio_fields",
                draftMode: false,
            });
            if (audio.fromStorage) {
                await (0, operational_cleanup_1.scheduleAudioCleanup)({ uid, storagePath: audio.storagePath, requestId });
            }
            return {
                result,
                transcription: (0, listing_pipeline_1.buildTranscriptionPayload)({
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
        pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
        cacheHit: operation.cacheHit,
    };
});
//# sourceMappingURL=listing_callables_v3.js.map