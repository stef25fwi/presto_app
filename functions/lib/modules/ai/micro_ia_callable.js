"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.microIaProcessAudioV2 = void 0;
const speech_1 = require("@google-cloud/speech");
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const logger_1 = require("../../core/logger");
const ai_metrics_1 = require("./ai_metrics");
const idempotency_1 = require("./idempotency");
const listing_pipeline_1 = require("./listing_pipeline");
const listing_taxonomy_1 = require("./listing_taxonomy");
const operational_cleanup_1 = require("./operational_cleanup");
let speechClient = null;
function getSpeechClient() {
    speechClient ??= new speech_1.SpeechClient();
    return speechClient;
}
function googleEncoding(contentType) {
    if (contentType.includes("webm"))
        return "WEBM_OPUS";
    if (contentType.includes("ogg"))
        return "OGG_OPUS";
    if (contentType.includes("flac"))
        return "FLAC";
    if (contentType.includes("mpeg") || contentType.includes("mp3"))
        return "MP3";
    if (contentType.includes("wav"))
        return "LINEAR16";
    return null;
}
function googleEligible(audio) {
    return googleEncoding(audio.contentType) != null;
}
async function transcribeWithGoogle(options) {
    const startedAtMs = Date.now();
    const encoding = googleEncoding(options.audio.contentType);
    if (!encoding) {
        throw new https_1.HttpsError("failed-precondition", "GOOGLE_STT_UNSUPPORTED_AUDIO");
    }
    try {
        const [response] = await getSpeechClient().recognize({
            audio: { content: options.audio.buffer.toString("base64") },
            config: {
                encoding,
                languageCode: options.languageCode || "fr-FR",
                model: "latest_short",
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
        }, { timeout: 12_000 });
        const alternatives = (response.results || []).flatMap((result) => {
            const alternative = result.alternatives?.[0];
            return alternative ? [alternative] : [];
        });
        const text = (0, listing_taxonomy_1.correctAntillesTranscript)(alternatives.map((item) => item.transcript || "").join(" "));
        const confidenceValues = alternatives
            .map((item) => Number(item.confidence))
            .filter((value) => Number.isFinite(value) && value > 0);
        const confidence = confidenceValues.length
            ? confidenceValues.reduce((sum, value) => sum + value, 0) /
                confidenceValues.length
            : null;
        if (!text) {
            throw new https_1.HttpsError("failed-precondition", "AUDIO_TRANSCRIPT_EMPTY");
        }
        await (0, ai_metrics_1.recordAiMetric)({
            operation: "micro_ia_google_stt",
            provider: "google",
            model: "latest_short",
            success: true,
            durationMs: Date.now() - startedAtMs,
            audioSeconds: options.audio.durationSeconds,
            pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
        });
        return { text, confidence };
    }
    catch (error) {
        await (0, ai_metrics_1.recordAiMetric)({
            operation: "micro_ia_google_stt",
            provider: "google",
            model: "latest_short",
            success: false,
            durationMs: Date.now() - startedAtMs,
            audioSeconds: options.audio.durationSeconds,
            errorCode: error instanceof Error ? error.message : "unknown",
            pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
        });
        throw error;
    }
}
function qualityThreshold() {
    const parsed = Number(process.env.MICRO_IA_GOOGLE_QUALITY_THRESHOLD || 0.62);
    return Number.isFinite(parsed) ? Math.max(0.3, Math.min(0.9, parsed)) : 0.62;
}
function mapPipelineError(error) {
    if (error instanceof https_1.HttpsError)
        return error;
    const value = error;
    const code = String(value?.code || "").toLowerCase();
    const message = String(value?.message || "").toLowerCase();
    if (code.includes("deadline") || code === "4" || message.includes("deadline")) {
        return new https_1.HttpsError("deadline-exceeded", "AI_TIMEOUT", { retryable: true });
    }
    if (code === "8" || message.includes("resource exhausted")) {
        return new https_1.HttpsError("resource-exhausted", "AI_RATE_LIMITED", {
            retryable: true,
        });
    }
    if (code === "14" || message.includes("unavailable")) {
        return new https_1.HttpsError("unavailable", "AI_PROVIDER_UNAVAILABLE", {
            retryable: true,
        });
    }
    return new https_1.HttpsError("internal", "AI_PIPELINE_FAILED", {
        retryable: false,
    });
}
exports.microIaProcessAudioV2 = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 90,
    minInstances: 1,
    memory: "512MiB",
    cpu: 1,
    secrets: [env_1.OPENAI_API_KEY],
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const totalStartedAtMs = Date.now();
    const uid = (0, listing_pipeline_1.assertAuthenticated)(request);
    const storagePath = (0, listing_pipeline_1.cleanString)(request.data?.storagePath) || "";
    const audioBase64 = (0, listing_pipeline_1.cleanString)(request.data?.audioBase64) || "";
    const audioContentType = (0, listing_pipeline_1.cleanString)(request.data?.audioContentType) || "";
    const languageCode = (0, listing_pipeline_1.cleanString)(request.data?.languageCode) || "fr-FR";
    const generateDraft = request.data?.generateDraft === true;
    const city = (0, listing_pipeline_1.cleanString)(request.data?.draftCity) || "";
    const category = (0, listing_pipeline_1.cleanString)(request.data?.draftCategory) || "";
    if (!storagePath && !audioBase64) {
        throw new https_1.HttpsError("invalid-argument", "AUDIO_REQUIRED");
    }
    await (0, listing_pipeline_1.enforceRateLimit)(uid, "micro_ia_process_v2", 12, 60);
    const requestId = (0, listing_pipeline_1.requestIdFrom)(request.data?.clientRequestId, [
        storagePath,
        audioBase64,
        audioContentType,
        languageCode,
        city,
        category,
        generateDraft,
        listing_pipeline_1.PIPELINE_VERSION,
    ]);
    const operation = await (0, idempotency_1.runIdempotentOperation)({
        uid,
        operation: "micro_ia_process_v2",
        requestId,
        execute: async () => {
            let audio = null;
            let completed = false;
            try {
                const downloadStartedAtMs = Date.now();
                audio = await (0, listing_pipeline_1.prepareAudioInput)({
                    uid,
                    storagePath,
                    audioBase64,
                    audioContentType,
                });
                const downloadMs = Date.now() - downloadStartedAtMs;
                const sttStartedAtMs = Date.now();
                let text = "";
                let confidence = null;
                let modeUsed = "OPENAI_TRANSCRIBE";
                let fallbackUsed = false;
                let googleQuality = null;
                if (googleEligible(audio)) {
                    try {
                        const googleResult = await transcribeWithGoogle({
                            audio,
                            languageCode,
                            requestId,
                        });
                        googleQuality = (0, listing_pipeline_1.evaluateTranscriptQuality)({
                            text: googleResult.text,
                            confidence: googleResult.confidence,
                            threshold: qualityThreshold(),
                        });
                        if (googleQuality.acceptable) {
                            text = googleResult.text;
                            confidence = googleResult.confidence;
                            modeUsed = "GOOGLE_ONLY";
                        }
                        else {
                            fallbackUsed = true;
                        }
                    }
                    catch (googleError) {
                        fallbackUsed = true;
                        logger_1.logger.warn("micro_ia.google_fallback", {
                            requestId,
                            errorName: googleError instanceof Error ? googleError.name : "Error",
                        });
                    }
                }
                else {
                    fallbackUsed = true;
                }
                if (!text) {
                    const openAiResult = await (0, listing_pipeline_1.transcribeWithOpenAi)({
                        audio,
                        languageCode,
                        requestId,
                        operation: "micro_ia_openai_transcription",
                    });
                    text = openAiResult.text;
                    modeUsed = "OPENAI_TRANSCRIBE";
                }
                const quality = (0, listing_pipeline_1.evaluateTranscriptQuality)({
                    text,
                    confidence,
                    threshold: 0.4,
                });
                const sttMs = Date.now() - sttStartedAtMs;
                let draft = null;
                let draftError = null;
                const draftStartedAtMs = Date.now();
                if (generateDraft && text) {
                    try {
                        const result = await (0, listing_pipeline_1.generateStructuredListing)({
                            input: text,
                            city,
                            category,
                            languageCode,
                            requestId,
                            operation: "micro_ia_listing_draft",
                            draftMode: true,
                        });
                        draft = (0, listing_pipeline_1.buildLegacyDraftPayload)(result);
                    }
                    catch (error) {
                        const mapped = mapPipelineError(error);
                        draftError = mapped.message;
                        logger_1.logger.warn("micro_ia.draft_non_fatal", {
                            requestId,
                            code: mapped.code,
                            message: mapped.message,
                        });
                    }
                }
                const draftMs = generateDraft ? Date.now() - draftStartedAtMs : 0;
                const totalMs = Date.now() - totalStartedAtMs;
                completed = true;
                await (0, ai_metrics_1.recordAiMetric)({
                    operation: "micro_ia_pipeline",
                    provider: "system",
                    model: modeUsed,
                    success: true,
                    durationMs: totalMs,
                    audioSeconds: audio.durationSeconds,
                    fallbackUsed,
                    pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
                });
                return {
                    modeUsed,
                    text,
                    quality,
                    meta: {
                        language: languageCode,
                        providerConfidence: confidence,
                        googleQuality,
                        pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
                        fallbackUsed,
                        audioDurationSeconds: audio.durationSeconds,
                    },
                    draft,
                    ...(draftError != null ? { draftError } : {}),
                    timings: {
                        downloadMs,
                        ffmpegMs: 0,
                        sttMs,
                        draftMs,
                        totalMs,
                    },
                    pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
                };
            }
            catch (error) {
                const mapped = mapPipelineError(error);
                await (0, ai_metrics_1.recordAiMetric)({
                    operation: "micro_ia_pipeline",
                    provider: "system",
                    model: "v2",
                    success: false,
                    durationMs: Date.now() - totalStartedAtMs,
                    audioSeconds: audio?.durationSeconds,
                    errorCode: mapped.message,
                    pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
                });
                throw mapped;
            }
            finally {
                if (audio?.fromStorage) {
                    await (0, operational_cleanup_1.scheduleAudioCleanup)({
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
        await (0, ai_metrics_1.recordAiMetric)({
            operation: "micro_ia_pipeline",
            provider: "cache",
            model: "idempotency",
            success: true,
            durationMs: Date.now() - totalStartedAtMs,
            cacheHit: true,
            pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
        });
    }
    return {
        ...operation.value,
        cacheHit: operation.cacheHit,
        pipelineVersion: listing_pipeline_1.PIPELINE_VERSION,
    };
});
//# sourceMappingURL=micro_ia_callable.js.map