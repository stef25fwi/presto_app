"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.estimateAudioDurationSeconds = exports.PIPELINE_VERSION = exports.LISTING_SCHEMA_VERSION = exports.LISTING_PROMPT_VERSION = exports.TRANSCRIPTION_FALLBACK_MODEL = exports.TRANSCRIPTION_MODEL = exports.LISTING_MODEL = void 0;
exports.cleanString = cleanString;
exports.buildLegacyDraftPayload = buildLegacyDraftPayload;
exports.assertAuthenticated = assertAuthenticated;
exports.enforceRateLimit = enforceRateLimit;
exports.requestIdFrom = requestIdFrom;
exports.mapOpenAiError = mapOpenAiError;
exports.generateStructuredListing = generateStructuredListing;
exports.prepareAudioInput = prepareAudioInput;
exports.transcribeWithOpenAi = transcribeWithOpenAi;
exports.evaluateTranscriptQuality = evaluateTranscriptQuality;
exports.buildTranscriptionPayload = buildTranscriptionPayload;
const node_path_1 = __importDefault(require("node:path"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const openai_1 = require("openai");
const logger_1 = require("../../core/logger");
const ai_metrics_1 = require("./ai_metrics");
const audio_duration_1 = require("./audio_duration");
Object.defineProperty(exports, "estimateAudioDurationSeconds", { enumerable: true, get: function () { return audio_duration_1.estimateAudioDurationSeconds; } });
const idempotency_1 = require("./idempotency");
const listing_taxonomy_1 = require("./listing_taxonomy");
const openai_runtime_1 = require("./openai_runtime");
if (firebase_admin_1.default.apps.length === 0) {
    firebase_admin_1.default.initializeApp();
}
exports.LISTING_MODEL = process.env.OPENAI_LISTING_MODEL?.trim() || "gpt-4o-mini";
exports.TRANSCRIPTION_MODEL = process.env.OPENAI_TRANSCRIBE_MODEL?.trim() ||
    "gpt-4o-mini-transcribe";
exports.TRANSCRIPTION_FALLBACK_MODEL = "whisper-1";
exports.LISTING_PROMPT_VERSION = "ilipresto-listing-v3";
exports.LISTING_SCHEMA_VERSION = "ilipresto-listing-schema-v3";
exports.PIPELINE_VERSION = "ilipresto-ai-pipeline-v3";
const MAX_TEXT_LENGTH = 6_000;
const MAX_AUDIO_BYTES = 20_000_000;
const ALLOWED_AUDIO_CONTENT_TYPES = new Set([
    "audio/wav",
    "audio/x-wav",
    "audio/wave",
    "audio/vnd.wave",
    "audio/webm",
    "video/webm",
    "audio/mp4",
    "video/mp4",
    "audio/x-m4a",
    "audio/aac",
    "audio/mpeg",
    "audio/mp3",
    "audio/ogg",
    "audio/flac",
]);
const LISTING_RESPONSE_FORMAT = {
    type: "json_schema",
    json_schema: {
        name: "ilipresto_listing_result",
        strict: true,
        schema: {
            type: "object",
            additionalProperties: false,
            properties: {
                title: { type: ["string", "null"] },
                description: { type: ["string", "null"] },
                category: {
                    anyOf: [
                        { type: "string", enum: [...listing_taxonomy_1.LISTING_CATEGORY_VALUES] },
                        { type: "null" },
                    ],
                },
                subcategory: { type: ["string", "null"] },
                city: { type: ["string", "null"] },
                postalCode: { type: ["string", "null"] },
                price: { type: ["number", "null"] },
                currency: { type: ["string", "null"] },
                listingType: { type: ["string", "null"] },
                urgency: { type: ["string", "null"] },
                contactPreference: { type: ["string", "null"] },
                keywords: {
                    type: "array",
                    maxItems: 8,
                    items: { type: "string" },
                },
                details: {
                    type: "array",
                    maxItems: 6,
                    items: { type: "string" },
                },
                questionsToAsk: {
                    type: "array",
                    maxItems: 5,
                    items: { type: "string" },
                },
                confidenceScore: {
                    anyOf: [
                        { type: "number", minimum: 0, maximum: 1 },
                        { type: "null" },
                    ],
                },
            },
            required: [
                "title",
                "description",
                "category",
                "subcategory",
                "city",
                "postalCode",
                "price",
                "currency",
                "listingType",
                "urgency",
                "contactPreference",
                "keywords",
                "details",
                "questionsToAsk",
                "confidenceScore",
            ],
        },
    },
};
const LISTING_SYSTEM_PROMPT = `Tu es l'assistant de rédaction d'annonces de l'application iliprestō.

Transforme uniquement les informations réellement présentes dans le texte en un brouillon clair et fidèle.

Règles absolues :
- N'invente aucune information, aucun prix, aucune urgence, aucune disponibilité et aucune qualification.
- Utilise null ou [] lorsqu'une donnée est absente ou ambiguë.
- Corrige seulement les hésitations, répétitions et erreurs évidentes de transcription.
- Le titre doit être spécifique, naturel et court.
- La description doit être publiable, fidèle et concise.
- Les détails ne doivent pas répéter la description.
- La catégorie doit provenir exclusivement de l'enum du schéma.
- La ville et la catégorie fournies en contexte sont uniquement des indices prudents.
- Respecte strictement le schéma de sortie.`;
function cleanString(value) {
    if (typeof value !== "string")
        return null;
    const normalized = value.replace(/\s+/g, " ").trim();
    return normalized || null;
}
function cleanStringList(value) {
    if (!Array.isArray(value))
        return [];
    return value
        .map((item) => cleanString(item))
        .filter((item) => item != null)
        .slice(0, 12);
}
function clampConfidence(value) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed))
        return 0;
    return Math.max(0, Math.min(1, parsed));
}
function deterministicTitle(input) {
    const sentence = input.split(/[.!?\n]/)[0]?.trim() || input.trim();
    const words = sentence.split(/\s+/).filter(Boolean).slice(0, 10);
    const candidate = words.join(" ").slice(0, 90).trim();
    if (!candidate)
        return "";
    return candidate.charAt(0).toUpperCase() + candidate.slice(1);
}
function normalizeListingResult(raw, options) {
    const source = (0, listing_taxonomy_1.correctAntillesTranscript)(options.input);
    const title = cleanString(raw.title) || deterministicTitle(source);
    const description = cleanString(raw.description) || source;
    const category = (0, listing_taxonomy_1.normalizeListingCategory)(raw.category) ||
        (0, listing_taxonomy_1.normalizeListingCategory)(options.category);
    const city = cleanString(raw.city) || cleanString(options.city);
    const explicitPostalCode = cleanString(raw.postalCode);
    const postalCode = explicitPostalCode && /^\d{5}$/.test(explicitPostalCode)
        ? explicitPostalCode
        : (0, listing_taxonomy_1.findPostalCode)(city);
    const parsedPrice = Number(raw.price);
    const price = raw.price != null && Number.isFinite(parsedPrice) ? parsedPrice : null;
    const currency = (cleanString(raw.currency) || "EUR").toUpperCase();
    const missingFields = [
        !title ? "title" : null,
        !description ? "description" : null,
        !category ? "category" : null,
        !city ? "city" : null,
        !postalCode ? "postalCode" : null,
    ].filter((value) => value != null);
    const confidence = raw.confidenceScore == null
        ? Number(Math.max(0, (5 - missingFields.length) / 5).toFixed(2))
        : clampConfidence(raw.confidenceScore);
    return {
        title,
        description,
        category,
        subcategory: cleanString(raw.subcategory),
        city,
        postalCode,
        department: (0, listing_taxonomy_1.departmentFromPostalCode)(postalCode),
        price,
        currency,
        listingType: cleanString(raw.listingType),
        urgency: cleanString(raw.urgency),
        contactPreference: cleanString(raw.contactPreference),
        keywords: cleanStringList(raw.keywords),
        details: cleanStringList(raw.details),
        missingFields,
        questionsToAsk: cleanStringList(raw.questionsToAsk),
        confidenceScore: confidence,
        taxonomyVersion: listing_taxonomy_1.LISTING_TAXONOMY_VERSION,
    };
}
function buildLegacyDraftPayload(result) {
    return {
        title: result.title,
        description: result.description,
        category: result.category || "Autre",
        city: result.city || "",
        postalCode: result.postalCode || "",
        titre: result.title,
        suggestions_titres: [],
        description_courte: result.description,
        categorie: result.category,
        sous_categorie: result.subcategory,
        ville: result.city || "",
        secteur: null,
        budget: {
            type: result.price != null ? "fixe" : null,
            min: result.price,
            max: result.price,
            devise: result.currency,
        },
        urgence: result.urgency,
        details: result.details,
        competences_requises: [],
        materiel: { fourni_par_demandeur: [], a_prevoir_par_prestataire: [] },
        disponibilites: null,
        questions_a_poser: result.questionsToAsk,
        questionsToAsk: result.questionsToAsk,
        missingFields: result.missingFields,
        confidenceScore: result.confidenceScore,
        taxonomyVersion: result.taxonomyVersion,
    };
}
function assertAuthenticated(request) {
    const uid = cleanString(request.auth?.uid);
    if (!uid)
        throw new https_1.HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
    return uid;
}
async function enforceRateLimit(uid, action, limit, windowSeconds) {
    const now = Date.now();
    const bucket = Math.floor(now / (windowSeconds * 1000));
    const ref = firebase_admin_1.default
        .firestore()
        .collection("_rate_limits")
        .doc(`${action}_${uid}_${bucket}`);
    await firebase_admin_1.default.firestore().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const previous = snapshot.exists ? Number(snapshot.data()?.count || 0) : 0;
        const next = previous + 1;
        if (next > limit) {
            throw new https_1.HttpsError("resource-exhausted", "AI_RATE_LIMITED", {
                retryable: true,
            });
        }
        transaction.set(ref, {
            uid,
            action,
            bucket,
            count: next,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            expiresAt: firebase_admin_1.default.firestore.Timestamp.fromMillis((bucket + 1) * windowSeconds * 1000),
        }, { merge: true });
    });
}
function requestIdFrom(supplied, fallbackParts) {
    return (0, idempotency_1.normalizeClientRequestId)(supplied) || (0, idempotency_1.deriveClientRequestId)(fallbackParts);
}
function mapOpenAiError(error, stage) {
    if (error instanceof https_1.HttpsError)
        return error;
    const info = (0, openai_runtime_1.classifyOpenAiError)(error);
    const details = {
        retryable: info.retryable,
        stage,
        providerRequestId: info.requestId,
    };
    if (info.quotaExhausted) {
        return new https_1.HttpsError("resource-exhausted", "AI_QUOTA_EXHAUSTED", {
            ...details,
            retryable: false,
        });
    }
    if (info.timeout) {
        return new https_1.HttpsError("deadline-exceeded", "AI_TIMEOUT", details);
    }
    if (info.status === 429) {
        return new https_1.HttpsError("resource-exhausted", "AI_RATE_LIMITED", details);
    }
    if (info.status === 401 || info.status === 403) {
        return new https_1.HttpsError("failed-precondition", "AI_PROVIDER_CONFIGURATION_ERROR", { ...details, retryable: false });
    }
    if (info.retryable) {
        return new https_1.HttpsError("unavailable", "AI_PROVIDER_UNAVAILABLE", details);
    }
    return new https_1.HttpsError("internal", "AI_PROVIDER_ERROR", {
        ...details,
        retryable: false,
    });
}
async function generateStructuredListing(options) {
    const input = (0, listing_taxonomy_1.correctAntillesTranscript)(options.input);
    if (!input)
        throw new https_1.HttpsError("invalid-argument", "INPUT_REQUIRED");
    if (input.length > MAX_TEXT_LENGTH) {
        throw new https_1.HttpsError("invalid-argument", "INPUT_TOO_LONG");
    }
    const client = (0, openai_runtime_1.getOpenAiClient)();
    const startedAtMs = Date.now();
    const context = {
        operation: options.operation,
        requestId: options.requestId,
        model: exports.LISTING_MODEL,
        promptVersion: exports.LISTING_PROMPT_VERSION,
        schemaVersion: exports.LISTING_SCHEMA_VERSION,
        startedAtMs,
    };
    try {
        const completion = await client.chat.completions.create({
            model: exports.LISTING_MODEL,
            temperature: 0.1,
            max_tokens: 500,
            response_format: LISTING_RESPONSE_FORMAT,
            messages: [
                { role: "system", content: LISTING_SYSTEM_PROMPT },
                {
                    role: "user",
                    content: `${options.draftMode ? "Crée un brouillon prudent." : "Extrais les champs explicites."}\n\n` +
                        `Texte source :\n${input}\n\n` +
                        `Contexte facultatif :\n- Ville : ${options.city || "non précisée"}\n` +
                        `- Catégorie : ${options.category || "non précisée"}\n` +
                        `- Langue : ${options.languageCode || "fr-FR"}\n` +
                        `- Taxonomie : ${listing_taxonomy_1.LISTING_TAXONOMY_VERSION}`,
                },
            ],
        }, { timeout: 18_000, maxRetries: 1 });
        (0, openai_runtime_1.logOpenAiSuccess)(context, completion);
        const message = completion.choices[0]?.message;
        const refusal = cleanString(message?.refusal);
        if (refusal) {
            throw new https_1.HttpsError("failed-precondition", "AI_REFUSAL", {
                retryable: false,
                stage: "structured_output",
            });
        }
        if (completion.choices[0]?.finish_reason === "length") {
            throw new https_1.HttpsError("internal", "AI_OUTPUT_INCOMPLETE", {
                retryable: true,
                stage: "structured_output",
            });
        }
        const content = cleanString(message?.content);
        if (!content) {
            throw new https_1.HttpsError("internal", "AI_OUTPUT_EMPTY", {
                retryable: true,
                stage: "structured_output",
            });
        }
        let parsed;
        try {
            parsed = JSON.parse(content);
        }
        catch {
            throw new https_1.HttpsError("internal", "AI_OUTPUT_INVALID", {
                retryable: false,
                stage: "structured_output",
            });
        }
        const result = normalizeListingResult(parsed, {
            input,
            city: options.city,
            category: options.category,
        });
        const usage = completion.usage;
        await (0, ai_metrics_1.recordAiMetric)({
            operation: options.operation,
            provider: "openai",
            model: exports.LISTING_MODEL,
            success: true,
            durationMs: Date.now() - startedAtMs,
            inputTokens: usage?.prompt_tokens,
            cachedInputTokens: usage?.prompt_tokens_details?.cached_tokens,
            outputTokens: usage?.completion_tokens,
            pipelineVersion: exports.PIPELINE_VERSION,
        });
        return result;
    }
    catch (error) {
        const mapped = mapOpenAiError(error, "listing_generation");
        if (!(error instanceof https_1.HttpsError))
            (0, openai_runtime_1.logOpenAiFailure)(context, error);
        await (0, ai_metrics_1.recordAiMetric)({
            operation: options.operation,
            provider: "openai",
            model: exports.LISTING_MODEL,
            success: false,
            durationMs: Date.now() - startedAtMs,
            errorCode: mapped.message,
            pipelineVersion: exports.PIPELINE_VERSION,
        });
        throw mapped;
    }
}
async function prepareAudioInput(options) {
    const inlineBase64 = cleanString(options.audioBase64);
    const storagePath = cleanString(options.storagePath) || "";
    if (inlineBase64) {
        const contentType = cleanString(options.audioContentType)?.toLowerCase() || "";
        if (!ALLOWED_AUDIO_CONTENT_TYPES.has(contentType)) {
            throw new https_1.HttpsError("failed-precondition", "AUDIO_TYPE_UNSUPPORTED");
        }
        const buffer = Buffer.from(inlineBase64.replace(/\s+/g, ""), "base64");
        if (!buffer.length)
            throw new https_1.HttpsError("failed-precondition", "AUDIO_EMPTY");
        if (buffer.length > MAX_AUDIO_BYTES) {
            throw new https_1.HttpsError("failed-precondition", "AUDIO_TOO_LARGE");
        }
        const extension = contentType.includes("webm")
            ? ".webm"
            : contentType.includes("mp4") || contentType.includes("m4a")
                ? ".m4a"
                : contentType.includes("mpeg") || contentType.includes("mp3")
                    ? ".mp3"
                    : contentType.includes("ogg")
                        ? ".ogg"
                        : contentType.includes("flac")
                            ? ".flac"
                            : ".wav";
        return {
            buffer,
            contentType,
            fileName: `audio${extension}`,
            storagePath: "",
            generation: "inline",
            fromStorage: false,
            durationSeconds: (0, audio_duration_1.estimateAudioDurationSeconds)(buffer, contentType),
        };
    }
    if (!storagePath ||
        storagePath.includes("..") ||
        storagePath.startsWith("/") ||
        storagePath.includes("\\")) {
        throw new https_1.HttpsError("invalid-argument", "AUDIO_PATH_INVALID");
    }
    const ownsPath = storagePath.startsWith(`stt/${options.uid}_`) ||
        storagePath.startsWith(`stt_streaming/${options.uid}/`);
    if (!ownsPath)
        throw new https_1.HttpsError("permission-denied", "AUDIO_PATH_NOT_OWNED");
    const file = firebase_admin_1.default.storage().bucket().file(storagePath);
    let metadata;
    try {
        const [rawMetadata] = await file.getMetadata();
        metadata = rawMetadata;
    }
    catch {
        throw new https_1.HttpsError("not-found", "AUDIO_NOT_FOUND");
    }
    const size = Number(metadata.size || 0);
    const contentType = cleanString(metadata.contentType)?.toLowerCase() || "";
    if (!Number.isFinite(size) || size <= 0) {
        throw new https_1.HttpsError("failed-precondition", "AUDIO_EMPTY");
    }
    if (size > MAX_AUDIO_BYTES) {
        throw new https_1.HttpsError("failed-precondition", "AUDIO_TOO_LARGE");
    }
    if (!ALLOWED_AUDIO_CONTENT_TYPES.has(contentType)) {
        throw new https_1.HttpsError("failed-precondition", "AUDIO_TYPE_UNSUPPORTED");
    }
    const [buffer] = await file.download();
    if (!buffer.length)
        throw new https_1.HttpsError("failed-precondition", "AUDIO_EMPTY");
    return {
        buffer,
        contentType,
        fileName: node_path_1.default.basename(storagePath) || "audio.wav",
        storagePath,
        generation: cleanString(metadata.generation) || "",
        fromStorage: true,
        durationSeconds: (0, audio_duration_1.estimateAudioDurationSeconds)(buffer, contentType),
    };
}
function canFallbackTranscriptionModel(error) {
    const info = (0, openai_runtime_1.classifyOpenAiError)(error);
    const code = (info.code || "").toLowerCase();
    return (info.status === 403 ||
        info.status === 404 ||
        code.includes("model_not_found") ||
        code.includes("unsupported_model"));
}
async function transcribeWithOpenAi(options) {
    const client = (0, openai_runtime_1.getOpenAiClient)();
    const language = options.languageCode.toLowerCase().startsWith("fr")
        ? "fr"
        : undefined;
    const attempt = async (model) => {
        const startedAtMs = Date.now();
        const context = {
            operation: options.operation,
            requestId: options.requestId,
            model,
            promptVersion: "ilipresto-transcription-context-v2",
            startedAtMs,
        };
        try {
            const file = await (0, openai_1.toFile)(options.audio.buffer, options.audio.fileName, {
                type: options.audio.contentType,
            });
            const response = await client.audio.transcriptions.create({
                file,
                model,
                language,
                prompt: listing_taxonomy_1.ANTILLES_TRANSCRIPTION_CONTEXT,
                response_format: "json",
            }, { timeout: 45_000, maxRetries: 1 });
            (0, openai_runtime_1.logOpenAiSuccess)(context, response);
            const text = (0, listing_taxonomy_1.correctAntillesTranscript)(response.text);
            if (!text) {
                throw new https_1.HttpsError("failed-precondition", "AUDIO_TRANSCRIPT_EMPTY", {
                    retryable: false,
                });
            }
            await (0, ai_metrics_1.recordAiMetric)({
                operation: options.operation,
                provider: "openai",
                model,
                success: true,
                durationMs: Date.now() - startedAtMs,
                audioSeconds: options.audio.durationSeconds,
                pipelineVersion: exports.PIPELINE_VERSION,
            });
            return text;
        }
        catch (error) {
            if (!(error instanceof https_1.HttpsError))
                (0, openai_runtime_1.logOpenAiFailure)(context, error);
            await (0, ai_metrics_1.recordAiMetric)({
                operation: options.operation,
                provider: "openai",
                model,
                success: false,
                durationMs: Date.now() - startedAtMs,
                audioSeconds: options.audio.durationSeconds,
                errorCode: error instanceof Error ? error.message : "unknown",
                pipelineVersion: exports.PIPELINE_VERSION,
            });
            throw error;
        }
    };
    try {
        return { text: await attempt(exports.TRANSCRIPTION_MODEL), provider: exports.TRANSCRIPTION_MODEL };
    }
    catch (primaryError) {
        if (exports.TRANSCRIPTION_MODEL !== exports.TRANSCRIPTION_FALLBACK_MODEL &&
            canFallbackTranscriptionModel(primaryError)) {
            logger_1.logger.warn("openai.transcription.model_fallback", {
                requestId: options.requestId,
                fromModel: exports.TRANSCRIPTION_MODEL,
                toModel: exports.TRANSCRIPTION_FALLBACK_MODEL,
            });
            try {
                return {
                    text: await attempt(exports.TRANSCRIPTION_FALLBACK_MODEL),
                    provider: exports.TRANSCRIPTION_FALLBACK_MODEL,
                };
            }
            catch (fallbackError) {
                throw mapOpenAiError(fallbackError, "transcription");
            }
        }
        throw mapOpenAiError(primaryError, "transcription");
    }
}
function evaluateTranscriptQuality(options) {
    const text = (0, listing_taxonomy_1.correctAntillesTranscript)(options.text);
    const words = text.split(/\s+/).filter(Boolean);
    const confidence = Number.isFinite(Number(options.confidence))
        ? Math.max(0, Math.min(1, Number(options.confidence)))
        : null;
    const threshold = Math.max(0.1, Math.min(0.95, options.threshold ?? 0.62));
    const lengthScore = Math.min(1, text.length / 80);
    const wordScore = Math.min(1, words.length / 12);
    const confidenceScore = confidence ?? Math.min(0.8, (lengthScore + wordScore) / 2);
    const score = Number(Math.max(0, Math.min(1, confidenceScore * 0.7 + lengthScore * 0.15 + wordScore * 0.15)).toFixed(3));
    const reasons = [];
    if (text.length < 12)
        reasons.push("text_too_short");
    if (words.length < 3)
        reasons.push("too_few_words");
    if (confidence != null && confidence < threshold)
        reasons.push("low_confidence");
    const acceptable = text.length >= 12 &&
        words.length >= 3 &&
        (confidence == null ? score >= Math.min(0.5, threshold) : confidence >= threshold);
    return {
        score,
        wordCount: words.length,
        textLength: text.length,
        confidence,
        acceptable,
        reasons,
    };
}
function buildTranscriptionPayload(options) {
    return {
        text: options.text,
        provider: options.provider,
        languageCode: options.languageCode,
        storagePath: options.storagePath,
        durationSeconds: options.durationSeconds ?? null,
        confidence: options.confidence ?? null,
        pipelineVersion: exports.PIPELINE_VERSION,
    };
}
//# sourceMappingURL=listing_pipeline.js.map