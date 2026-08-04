import path from "node:path";

import admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { toFile } from "openai";

import { logger } from "../../core/logger";
import { recordAiMetric } from "./ai_metrics";
import { estimateAudioDurationSeconds } from "./audio_duration";
import { deriveClientRequestId, normalizeClientRequestId } from "./idempotency";
import {
  ANTILLES_TRANSCRIPTION_CONTEXT,
  departmentFromPostalCode,
  findPostalCode,
  correctAntillesTranscript,
  LISTING_CATEGORY_VALUES,
  LISTING_TAXONOMY_VERSION,
  normalizeListingCategory,
} from "./listing_taxonomy";
import {
  classifyOpenAiError,
  getOpenAiClient,
  logOpenAiFailure,
  logOpenAiSuccess,
} from "./openai_runtime";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const LISTING_MODEL =
  process.env.OPENAI_LISTING_MODEL?.trim() || "gpt-4o-mini";
export const TRANSCRIPTION_MODEL =
  process.env.OPENAI_TRANSCRIBE_MODEL?.trim() ||
  "gpt-4o-mini-transcribe";
export const TRANSCRIPTION_FALLBACK_MODEL = "whisper-1";
export const LISTING_PROMPT_VERSION = "ilipresto-listing-v3";
export const LISTING_SCHEMA_VERSION = "ilipresto-listing-schema-v3";
export const PIPELINE_VERSION = "ilipresto-ai-pipeline-v3";

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

export interface StructuredListingOutput {
  title: string | null;
  description: string | null;
  category: string | null;
  subcategory: string | null;
  city: string | null;
  postalCode: string | null;
  price: number | null;
  currency: string | null;
  listingType: string | null;
  urgency: string | null;
  contactPreference: string | null;
  keywords: string[];
  details: string[];
  questionsToAsk: string[];
  confidenceScore: number | null;
}

export interface NormalizedListingResult extends Record<string, unknown> {
  title: string;
  description: string;
  category: string | null;
  subcategory: string | null;
  city: string | null;
  postalCode: string | null;
  department: string | null;
  price: number | null;
  currency: string;
  listingType: string | null;
  urgency: string | null;
  contactPreference: string | null;
  keywords: string[];
  details: string[];
  missingFields: string[];
  questionsToAsk: string[];
  confidenceScore: number;
  taxonomyVersion: string;
}

export interface PreparedAudio {
  buffer: Buffer;
  contentType: string;
  fileName: string;
  storagePath: string;
  generation: string;
  fromStorage: boolean;
  durationSeconds: number | null;
}

export interface TranscriptQuality {
  score: number;
  wordCount: number;
  textLength: number;
  confidence: number | null;
  acceptable: boolean;
  reasons: string[];
}

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
            { type: "string", enum: [...LISTING_CATEGORY_VALUES] },
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
} as const;

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

export function cleanString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.replace(/\s+/g, " ").trim();
  return normalized || null;
}

function cleanStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => cleanString(item))
    .filter((item): item is string => item != null)
    .slice(0, 12);
}

function clampConfidence(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.min(1, parsed));
}

function deterministicTitle(input: string): string {
  const sentence = input.split(/[.!?\n]/)[0]?.trim() || input.trim();
  const words = sentence.split(/\s+/).filter(Boolean).slice(0, 10);
  const candidate = words.join(" ").slice(0, 90).trim();
  if (!candidate) return "";
  return candidate.charAt(0).toUpperCase() + candidate.slice(1);
}

function normalizeListingResult(
  raw: StructuredListingOutput,
  options: { input: string; city: string; category: string },
): NormalizedListingResult {
  const source = correctAntillesTranscript(options.input);
  const title = cleanString(raw.title) || deterministicTitle(source);
  const description = cleanString(raw.description) || source;
  const category =
    normalizeListingCategory(raw.category) ||
    normalizeListingCategory(options.category);
  const city = cleanString(raw.city) || cleanString(options.city);
  const explicitPostalCode = cleanString(raw.postalCode);
  const postalCode =
    explicitPostalCode && /^\d{5}$/.test(explicitPostalCode)
      ? explicitPostalCode
      : findPostalCode(city);
  const parsedPrice = Number(raw.price);
  const price = raw.price != null && Number.isFinite(parsedPrice) ? parsedPrice : null;
  const currency = (cleanString(raw.currency) || "EUR").toUpperCase();
  const missingFields = [
    !title ? "title" : null,
    !description ? "description" : null,
    !category ? "category" : null,
    !city ? "city" : null,
    !postalCode ? "postalCode" : null,
  ].filter((value): value is string => value != null);
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
    department: departmentFromPostalCode(postalCode),
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
    taxonomyVersion: LISTING_TAXONOMY_VERSION,
  };
}

export function buildLegacyDraftPayload(
  result: NormalizedListingResult,
): Record<string, unknown> {
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

export function assertAuthenticated(request: { auth?: { uid?: string } | null }): string {
  const uid = cleanString(request.auth?.uid);
  if (!uid) throw new HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
  return uid;
}

export async function enforceRateLimit(
  uid: string,
  action: string,
  limit: number,
  windowSeconds: number,
): Promise<void> {
  const now = Date.now();
  const bucket = Math.floor(now / (windowSeconds * 1000));
  const ref = admin
    .firestore()
    .collection("_rate_limits")
    .doc(`${action}_${uid}_${bucket}`);
  await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const previous = snapshot.exists ? Number(snapshot.data()?.count || 0) : 0;
    const next = previous + 1;
    if (next > limit) {
      throw new HttpsError("resource-exhausted", "AI_RATE_LIMITED", {
        retryable: true,
      });
    }
    transaction.set(
      ref,
      {
        uid,
        action,
        bucket,
        count: next,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(
          (bucket + 1) * windowSeconds * 1000,
        ),
      },
      { merge: true },
    );
  });
}

export function requestIdFrom(
  supplied: unknown,
  fallbackParts: readonly unknown[],
): string {
  return normalizeClientRequestId(supplied) || deriveClientRequestId(fallbackParts);
}

export function mapOpenAiError(error: unknown, stage: string): HttpsError {
  if (error instanceof HttpsError) return error;
  const info = classifyOpenAiError(error);
  const details = {
    retryable: info.retryable,
    stage,
    providerRequestId: info.requestId,
  };
  if (info.quotaExhausted) {
    return new HttpsError("resource-exhausted", "AI_QUOTA_EXHAUSTED", {
      ...details,
      retryable: false,
    });
  }
  if (info.timeout) {
    return new HttpsError("deadline-exceeded", "AI_TIMEOUT", details);
  }
  if (info.status === 429) {
    return new HttpsError("resource-exhausted", "AI_RATE_LIMITED", details);
  }
  if (info.status === 401 || info.status === 403) {
    return new HttpsError(
      "failed-precondition",
      "AI_PROVIDER_CONFIGURATION_ERROR",
      { ...details, retryable: false },
    );
  }
  if (info.retryable) {
    return new HttpsError("unavailable", "AI_PROVIDER_UNAVAILABLE", details);
  }
  return new HttpsError("internal", "AI_PROVIDER_ERROR", {
    ...details,
    retryable: false,
  });
}

export async function generateStructuredListing(options: {
  input: string;
  city: string;
  category: string;
  languageCode: string;
  requestId: string;
  operation: string;
  draftMode: boolean;
}): Promise<NormalizedListingResult> {
  const input = correctAntillesTranscript(options.input);
  if (!input) throw new HttpsError("invalid-argument", "INPUT_REQUIRED");
  if (input.length > MAX_TEXT_LENGTH) {
    throw new HttpsError("invalid-argument", "INPUT_TOO_LONG");
  }
  const client = getOpenAiClient();
  const startedAtMs = Date.now();
  const context = {
    operation: options.operation,
    requestId: options.requestId,
    model: LISTING_MODEL,
    promptVersion: LISTING_PROMPT_VERSION,
    schemaVersion: LISTING_SCHEMA_VERSION,
    startedAtMs,
  };
  try {
    const completion = await client.chat.completions.create(
      {
        model: LISTING_MODEL,
        temperature: 0.1,
        max_tokens: 500,
        response_format: LISTING_RESPONSE_FORMAT as never,
        messages: [
          { role: "system", content: LISTING_SYSTEM_PROMPT },
          {
            role: "user",
            content:
              `${options.draftMode ? "Crée un brouillon prudent." : "Extrais les champs explicites."}\n\n` +
              `Texte source :\n${input}\n\n` +
              `Contexte facultatif :\n- Ville : ${options.city || "non précisée"}\n` +
              `- Catégorie : ${options.category || "non précisée"}\n` +
              `- Langue : ${options.languageCode || "fr-FR"}\n` +
              `- Taxonomie : ${LISTING_TAXONOMY_VERSION}`,
          },
        ],
      },
      { timeout: 18_000, maxRetries: 1 },
    );
    logOpenAiSuccess(context, completion);
    const message = completion.choices[0]?.message;
    const refusal = cleanString((message as { refusal?: unknown } | undefined)?.refusal);
    if (refusal) {
      throw new HttpsError("failed-precondition", "AI_REFUSAL", {
        retryable: false,
        stage: "structured_output",
      });
    }
    if (completion.choices[0]?.finish_reason === "length") {
      throw new HttpsError("internal", "AI_OUTPUT_INCOMPLETE", {
        retryable: true,
        stage: "structured_output",
      });
    }
    const content = cleanString(message?.content);
    if (!content) {
      throw new HttpsError("internal", "AI_OUTPUT_EMPTY", {
        retryable: true,
        stage: "structured_output",
      });
    }
    let parsed: StructuredListingOutput;
    try {
      parsed = JSON.parse(content) as StructuredListingOutput;
    } catch {
      throw new HttpsError("internal", "AI_OUTPUT_INVALID", {
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
    await recordAiMetric({
      operation: options.operation,
      provider: "openai",
      model: LISTING_MODEL,
      success: true,
      durationMs: Date.now() - startedAtMs,
      inputTokens: usage?.prompt_tokens,
      cachedInputTokens: usage?.prompt_tokens_details?.cached_tokens,
      outputTokens: usage?.completion_tokens,
      pipelineVersion: PIPELINE_VERSION,
    });
    return result;
  } catch (error) {
    const mapped = mapOpenAiError(error, "listing_generation");
    if (!(error instanceof HttpsError)) logOpenAiFailure(context, error);
    await recordAiMetric({
      operation: options.operation,
      provider: "openai",
      model: LISTING_MODEL,
      success: false,
      durationMs: Date.now() - startedAtMs,
      errorCode: mapped.message,
      pipelineVersion: PIPELINE_VERSION,
    });
    throw mapped;
  }
}

export { estimateAudioDurationSeconds };

export async function prepareAudioInput(options: {
  uid: string;
  storagePath?: unknown;
  audioBase64?: unknown;
  audioContentType?: unknown;
}): Promise<PreparedAudio> {
  const inlineBase64 = cleanString(options.audioBase64);
  const storagePath = cleanString(options.storagePath) || "";
  if (inlineBase64) {
    const contentType = cleanString(options.audioContentType)?.toLowerCase() || "";
    if (!ALLOWED_AUDIO_CONTENT_TYPES.has(contentType)) {
      throw new HttpsError("failed-precondition", "AUDIO_TYPE_UNSUPPORTED");
    }
    const buffer = Buffer.from(inlineBase64.replace(/\s+/g, ""), "base64");
    if (!buffer.length) throw new HttpsError("failed-precondition", "AUDIO_EMPTY");
    if (buffer.length > MAX_AUDIO_BYTES) {
      throw new HttpsError("failed-precondition", "AUDIO_TOO_LARGE");
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
      durationSeconds: estimateAudioDurationSeconds(buffer, contentType),
    };
  }
  if (
    !storagePath ||
    storagePath.includes("..") ||
    storagePath.startsWith("/") ||
    storagePath.includes("\\")
  ) {
    throw new HttpsError("invalid-argument", "AUDIO_PATH_INVALID");
  }
  const ownsPath =
    storagePath.startsWith(`stt/${options.uid}_`) ||
    storagePath.startsWith(`stt_streaming/${options.uid}/`);
  if (!ownsPath) throw new HttpsError("permission-denied", "AUDIO_PATH_NOT_OWNED");
  const file = admin.storage().bucket().file(storagePath);
  let metadata: Record<string, unknown>;
  try {
    const [rawMetadata] = await file.getMetadata();
    metadata = rawMetadata as unknown as Record<string, unknown>;
  } catch {
    throw new HttpsError("not-found", "AUDIO_NOT_FOUND");
  }
  const size = Number(metadata.size || 0);
  const contentType = cleanString(metadata.contentType)?.toLowerCase() || "";
  if (!Number.isFinite(size) || size <= 0) {
    throw new HttpsError("failed-precondition", "AUDIO_EMPTY");
  }
  if (size > MAX_AUDIO_BYTES) {
    throw new HttpsError("failed-precondition", "AUDIO_TOO_LARGE");
  }
  if (!ALLOWED_AUDIO_CONTENT_TYPES.has(contentType)) {
    throw new HttpsError("failed-precondition", "AUDIO_TYPE_UNSUPPORTED");
  }
  const [buffer] = await file.download();
  if (!buffer.length) throw new HttpsError("failed-precondition", "AUDIO_EMPTY");
  return {
    buffer,
    contentType,
    fileName: path.basename(storagePath) || "audio.wav",
    storagePath,
    generation: cleanString(metadata.generation) || "",
    fromStorage: true,
    durationSeconds: estimateAudioDurationSeconds(buffer, contentType),
  };
}

function canFallbackTranscriptionModel(error: unknown): boolean {
  const info = classifyOpenAiError(error);
  const code = (info.code || "").toLowerCase();
  return (
    info.status === 403 ||
    info.status === 404 ||
    code.includes("model_not_found") ||
    code.includes("unsupported_model")
  );
}

export async function transcribeWithOpenAi(options: {
  audio: PreparedAudio;
  languageCode: string;
  requestId: string;
  operation: string;
}): Promise<{ text: string; provider: string }> {
  const client = getOpenAiClient();
  const language = options.languageCode.toLowerCase().startsWith("fr")
    ? "fr"
    : undefined;
  const attempt = async (model: string): Promise<string> => {
    const startedAtMs = Date.now();
    const context = {
      operation: options.operation,
      requestId: options.requestId,
      model,
      promptVersion: "ilipresto-transcription-context-v2",
      startedAtMs,
    };
    try {
      const file = await toFile(options.audio.buffer, options.audio.fileName, {
        type: options.audio.contentType,
      });
      const response = await client.audio.transcriptions.create(
        {
          file,
          model,
          language,
          prompt: ANTILLES_TRANSCRIPTION_CONTEXT,
          response_format: "json",
        },
        { timeout: 45_000, maxRetries: 1 },
      );
      logOpenAiSuccess(context, response as unknown as {
        _request_id?: string | null;
        usage?: null;
      });
      const text = correctAntillesTranscript(response.text);
      if (!text) {
        throw new HttpsError("failed-precondition", "AUDIO_TRANSCRIPT_EMPTY", {
          retryable: false,
        });
      }
      await recordAiMetric({
        operation: options.operation,
        provider: "openai",
        model,
        success: true,
        durationMs: Date.now() - startedAtMs,
        audioSeconds: options.audio.durationSeconds,
        pipelineVersion: PIPELINE_VERSION,
      });
      return text;
    } catch (error) {
      if (!(error instanceof HttpsError)) logOpenAiFailure(context, error);
      await recordAiMetric({
        operation: options.operation,
        provider: "openai",
        model,
        success: false,
        durationMs: Date.now() - startedAtMs,
        audioSeconds: options.audio.durationSeconds,
        errorCode: error instanceof Error ? error.message : "unknown",
        pipelineVersion: PIPELINE_VERSION,
      });
      throw error;
    }
  };
  try {
    return { text: await attempt(TRANSCRIPTION_MODEL), provider: TRANSCRIPTION_MODEL };
  } catch (primaryError) {
    if (
      TRANSCRIPTION_MODEL !== TRANSCRIPTION_FALLBACK_MODEL &&
      canFallbackTranscriptionModel(primaryError)
    ) {
      logger.warn("openai.transcription.model_fallback", {
        requestId: options.requestId,
        fromModel: TRANSCRIPTION_MODEL,
        toModel: TRANSCRIPTION_FALLBACK_MODEL,
      });
      try {
        return {
          text: await attempt(TRANSCRIPTION_FALLBACK_MODEL),
          provider: TRANSCRIPTION_FALLBACK_MODEL,
        };
      } catch (fallbackError) {
        throw mapOpenAiError(fallbackError, "transcription");
      }
    }
    throw mapOpenAiError(primaryError, "transcription");
  }
}

export function evaluateTranscriptQuality(options: {
  text: string;
  confidence?: number | null;
  threshold?: number;
}): TranscriptQuality {
  const text = correctAntillesTranscript(options.text);
  const words = text.split(/\s+/).filter(Boolean);
  const confidence = Number.isFinite(Number(options.confidence))
    ? Math.max(0, Math.min(1, Number(options.confidence)))
    : null;
  const threshold = Math.max(0.1, Math.min(0.95, options.threshold ?? 0.62));
  const lengthScore = Math.min(1, text.length / 80);
  const wordScore = Math.min(1, words.length / 12);
  const confidenceScore = confidence ?? Math.min(0.8, (lengthScore + wordScore) / 2);
  const score = Number(
    Math.max(0, Math.min(1, confidenceScore * 0.7 + lengthScore * 0.15 + wordScore * 0.15)).toFixed(3),
  );
  const reasons: string[] = [];
  if (text.length < 12) reasons.push("text_too_short");
  if (words.length < 3) reasons.push("too_few_words");
  if (confidence != null && confidence < threshold) reasons.push("low_confidence");
  const acceptable =
    text.length >= 12 &&
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

export function buildTranscriptionPayload(options: {
  text: string;
  provider: string;
  languageCode: string;
  storagePath: string;
  durationSeconds?: number | null;
  confidence?: number | null;
}): Record<string, unknown> {
  return {
    text: options.text,
    provider: options.provider,
    languageCode: options.languageCode,
    storagePath: options.storagePath,
    durationSeconds: options.durationSeconds ?? null,
    confidence: options.confidence ?? null,
    pipelineVersion: PIPELINE_VERSION,
  };
}
