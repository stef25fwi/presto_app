import path from "node:path";

import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { toFile } from "openai";

import {
  ENFORCE_APP_CHECK,
  OPENAI_API_KEY,
  PROJECT_REGION,
} from "../../config/env";
import { logger } from "../../core/logger";
import {
  deriveClientRequestId,
  normalizeClientRequestId,
  runIdempotentOperation,
} from "./idempotency";
import {
  classifyOpenAiError,
  getOpenAiClient,
  logOpenAiFailure,
  logOpenAiSuccess,
} from "./openai_runtime";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const LISTING_MODEL =
  process.env.OPENAI_LISTING_MODEL?.trim() || "gpt-4o-mini-2024-07-18";
const TRANSCRIPTION_MODEL =
  process.env.OPENAI_TRANSCRIBE_MODEL?.trim() ||
  "gpt-4o-mini-transcribe-2025-12-15";
const TRANSCRIPTION_FALLBACK_MODEL = "whisper-1";
const PROMPT_VERSION = "ilipresto-listing-v2";
const SCHEMA_VERSION = "ilipresto-listing-schema-v2";
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
]);

const CATEGORY_VALUES = [
  "Jardinage",
  "Bricolage / Travaux",
  "Aide à domicile",
  "Restauration / Extra",
  "Événementiel / DJ",
  "Garde d'enfants",
  "Cours & soutien",
  "Peinture",
  "Main-d'œuvre",
  "Autre",
] as const;

const CITY_POSTAL_MAP: Record<string, string> = {
  "baie-mahault": "97122",
  "les abymes": "97139",
  "pointe-a-pitre": "97110",
  "le gosier": "97190",
  "sainte-anne": "97180",
  "saint-francois": "97118",
  "petit-bourg": "97170",
  lamentin: "97129",
  "capesterre-belle-eau": "97130",
  "basse-terre": "97100",
  goyave: "97128",
  "morne-a-l'eau": "97111",
  "sainte-rose": "97115",
  "le moule": "97160",
  "saint-claude": "97120",
  bouillante: "97125",
  deshaies: "97126",
  "trois-rivieres": "97114",
  "vieux-habitants": "97119",
  "vieux-fort": "97141",
  "anse-bertrand": "97121",
  "port-louis": "97117",
  "petit-canal": "97131",
  "la desirade": "97127",
  "terre-de-bas": "97136",
  "terre-de-haut": "97137",
  "fort-de-france": "97200",
  "le lamentin": "97232",
  schoelcher: "97233",
  "le robert": "97231",
  "le francois": "97240",
  "le marin": "97290",
  "les trois-ilets": "97229",
  "sainte-luce": "97228",
  "la trinite": "97220",
  "le lorrain": "97214",
  "le carbet": "97221",
  "le diamant": "97223",
  "saint-esprit": "97270",
};

interface StructuredListingOutput {
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

interface NormalizedListingResult extends Record<string, unknown> {
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
}

interface PreparedAudio {
  buffer: Buffer;
  contentType: string;
  fileName: string;
  storagePath: string;
  generation: string;
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
            { type: "string", enum: [...CATEGORY_VALUES] },
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
          maxItems: 4,
          items: { type: "string" },
        },
        questionsToAsk: {
          type: "array",
          maxItems: 4,
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

Objectif : extraire et reformuler uniquement les informations réellement présentes dans le texte utilisateur afin de préremplir un formulaire d'annonce.

Règles absolues :
- N'invente aucune information, aucun prix, aucune urgence et aucune disponibilité.
- Si une donnée est absente ou ambiguë, utilise null ou [].
- Corrige les hésitations et répétitions sans changer le sens.
- Le titre doit être spécifique, naturel et court.
- La description doit être publiable, fidèle et concise.
- Les détails ne doivent pas répéter la description.
- La catégorie doit être choisie uniquement dans l'enum du schéma.
- Une ville ou catégorie fournie comme contexte ne sert que de fallback prudent.
- Réponds uniquement selon le schéma structuré fourni.`;

const TRANSCRIPTION_CONTEXT_PROMPT =
  "iliprestō, Guadeloupe, Martinique, Baie-Mahault, Les Abymes, " +
  "Pointe-à-Pitre, Petit-Bourg, Le Gosier, Saint-François, Fort-de-France, " +
  "jardinage, bricolage, peinture, aide à domicile, déménagement, plomberie, électricité";

function cleanString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.replace(/\s+/g, " ").trim();
  return normalized || null;
}

function cleanStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => cleanString(item))
    .filter((item): item is string => item != null);
}

function normalizeCityKey(value: string): string {
  return value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[’']/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function findPostalCode(city: string | null): string | null {
  if (!city) return null;
  const normalized = normalizeCityKey(city);
  const direct = CITY_POSTAL_MAP[normalized];
  if (direct) return direct;
  const dashed = normalized.replace(/\s+/g, "-");
  return CITY_POSTAL_MAP[dashed] || null;
}

function normalizeDepartment(postalCode: string | null): string | null {
  if (!postalCode || !/^\d{5}$/.test(postalCode)) return null;
  return postalCode.startsWith("97") || postalCode.startsWith("98")
    ? postalCode.slice(0, 3)
    : postalCode.slice(0, 2);
}

function preprocessTranscript(value: unknown): string {
  let text = cleanString(value) || "";
  const corrections: Record<string, string> = {
    "baie ma haut": "Baie-Mahault",
    "baie mahaut": "Baie-Mahault",
    "bye mahaut": "Baie-Mahault",
    "les abîmes": "Les Abymes",
    "les zabîmes": "Les Abymes",
    "pointe à pitre": "Pointe-à-Pitre",
    "fort de france": "Fort-de-France",
    "petit bourg": "Petit-Bourg",
  };
  for (const [source, replacement] of Object.entries(corrections)) {
    text = text.replace(new RegExp(source, "gi"), replacement);
  }
  return text;
}

function clampConfidence(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.min(1, parsed));
}

function normalizeListingResult(
  raw: StructuredListingOutput,
  context: { city: string; category: string },
): NormalizedListingResult {
  const title = cleanString(raw.title) || "";
  const description = cleanString(raw.description) || "";
  if (!title || !description) {
    throw new HttpsError("internal", "AI_OUTPUT_INVALID", {
      retryable: false,
      stage: "structured_output",
    });
  }

  const rawCategory = cleanString(raw.category);
  const contextCategory = cleanString(context.category);
  const category = CATEGORY_VALUES.includes(rawCategory as (typeof CATEGORY_VALUES)[number])
    ? rawCategory
    : CATEGORY_VALUES.includes(contextCategory as (typeof CATEGORY_VALUES)[number])
      ? contextCategory
      : null;
  const city = cleanString(raw.city) || cleanString(context.city);
  const explicitPostalCode = cleanString(raw.postalCode);
  const postalCode =
    explicitPostalCode && /^\d{5}$/.test(explicitPostalCode)
      ? explicitPostalCode
      : findPostalCode(city);
  const parsedPrice = Number(raw.price);
  const price = raw.price != null && Number.isFinite(parsedPrice) ? parsedPrice : null;
  const currency = (cleanString(raw.currency) || "EUR").toUpperCase();
  const missingFields = [
    ifEmpty(title, "title"),
    ifEmpty(description, "description"),
    ifEmpty(category, "category"),
    ifEmpty(city, "city"),
    ifEmpty(postalCode, "postalCode"),
  ].filter((value): value is string => value != null);

  const confidence = raw.confidenceScore == null
    ? Number(((5 - missingFields.length) / 5).toFixed(2))
    : clampConfidence(raw.confidenceScore);

  return {
    title,
    description,
    category,
    subcategory: cleanString(raw.subcategory),
    city,
    postalCode,
    department: normalizeDepartment(postalCode),
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
  };
}

function ifEmpty(value: unknown, field: string): string | null {
  if (value == null) return field;
  if (typeof value === "string" && !value.trim()) return field;
  return null;
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
    budget: { type: null, min: null, max: null, devise: "EUR" },
    urgence: null,
    details: result.details,
    competences_requises: [],
    materiel: { fourni_par_demandeur: [], a_prevoir_par_prestataire: [] },
    disponibilites: null,
    questions_a_poser: result.questionsToAsk,
  };
}

function assertAuthenticated(request: { auth?: { uid?: string } | null }): string {
  const uid = cleanString(request.auth?.uid);
  if (!uid) {
    throw new HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
  }
  return uid;
}

async function enforceRateLimit(
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

function requestIdFrom(
  supplied: unknown,
  fallbackParts: readonly unknown[],
): string {
  return normalizeClientRequestId(supplied) || deriveClientRequestId(fallbackParts);
}

function mapOpenAiError(error: unknown, stage: string): HttpsError {
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

async function generateStructuredListing(options: {
  input: string;
  city: string;
  category: string;
  languageCode: string;
  requestId: string;
  operation: string;
  draftMode: boolean;
}): Promise<NormalizedListingResult> {
  const client = getOpenAiClient();
  const startedAtMs = Date.now();
  const context = {
    operation: options.operation,
    requestId: options.requestId,
    model: LISTING_MODEL,
    promptVersion: PROMPT_VERSION,
    schemaVersion: SCHEMA_VERSION,
    startedAtMs,
  };
  const modeInstruction = options.draftMode
    ? "Pour ce brouillon, laisse price, urgency et contactPreference à null même s'ils semblent implicites."
    : "Extrais les champs facultatifs uniquement lorsqu'ils sont explicitement présents.";

  try {
    const completion = await client.chat.completions.create(
      {
        model: LISTING_MODEL,
        temperature: 0.1,
        max_tokens: 450,
        response_format: LISTING_RESPONSE_FORMAT as never,
        messages: [
          { role: "system", content: LISTING_SYSTEM_PROMPT },
          {
            role: "user",
            content:
              `${modeInstruction}\n\nTexte source :\n${options.input}\n\n` +
              `Contexte facultatif :\n- Ville : ${options.city || "non précisée"}\n` +
              `- Catégorie : ${options.category || "non précisée"}\n` +
              `- Langue : ${options.languageCode || "fr-FR"}`,
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
    return normalizeListingResult(parsed, {
      city: options.city,
      category: options.category,
    });
  } catch (error) {
    if (!(error instanceof HttpsError)) {
      logOpenAiFailure(context, error);
    }
    throw mapOpenAiError(error, "listing_generation");
  }
}

async function prepareUploadedAudio(
  uid: string,
  storagePath: string,
): Promise<PreparedAudio> {
  if (
    !storagePath ||
    storagePath.includes("..") ||
    storagePath.startsWith("/") ||
    storagePath.includes("\\")
  ) {
    throw new HttpsError("invalid-argument", "AUDIO_PATH_INVALID");
  }
  const ownsPath =
    storagePath.startsWith(`stt/${uid}_`) ||
    storagePath.startsWith(`stt_streaming/${uid}/`);
  if (!ownsPath) {
    throw new HttpsError("permission-denied", "AUDIO_PATH_NOT_OWNED");
  }

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
  if (!buffer.length) {
    throw new HttpsError("failed-precondition", "AUDIO_EMPTY");
  }
  return {
    buffer,
    contentType,
    fileName: path.basename(storagePath) || "audio.wav",
    storagePath,
    generation: cleanString(metadata.generation) || "",
  };
}

function canFallbackTranscriptionModel(error: unknown): boolean {
  const info = classifyOpenAiError(error);
  const normalizedCode = (info.code || "").toLowerCase();
  return (
    info.status === 403 ||
    info.status === 404 ||
    normalizedCode.includes("model_not_found") ||
    normalizedCode.includes("unsupported_model")
  );
}

async function transcribeAudio(options: {
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
      promptVersion: "ilipresto-transcription-context-v1",
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
          prompt: TRANSCRIPTION_CONTEXT_PROMPT,
          response_format: "json",
        },
        { timeout: 55_000, maxRetries: 1 },
      );
      logOpenAiSuccess(context, response as unknown as {
        _request_id?: string | null;
        usage?: null;
      });
      const text = preprocessTranscript(response.text);
      if (!text) {
        throw new HttpsError("failed-precondition", "AUDIO_TRANSCRIPT_EMPTY", {
          retryable: false,
        });
      }
      return text;
    } catch (error) {
      if (!(error instanceof HttpsError)) {
        logOpenAiFailure(context, error);
      }
      throw error;
    }
  };

  try {
    return {
      text: await attempt(TRANSCRIPTION_MODEL),
      provider: TRANSCRIPTION_MODEL,
    };
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

function buildTranscriptionPayload(options: {
  text: string;
  provider: string;
  languageCode: string;
  storagePath: string;
}): Record<string, unknown> {
  return {
    text: options.text,
    provider: options.provider,
    languageCode: options.languageCode,
    storagePath: options.storagePath,
    durationSeconds: null,
    confidence: null,
  };
}

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
    const input = preprocessTranscript(request.data?.hint ?? request.data?.input);
    const city = cleanString(request.data?.city) || "";
    const category = cleanString(request.data?.category) || "";
    const languageCode = cleanString(request.data?.lang) || "fr";
    if (!input) throw new HttpsError("invalid-argument", "INPUT_REQUIRED");
    if (input.length > MAX_TEXT_LENGTH) {
      throw new HttpsError("invalid-argument", "INPUT_TOO_LONG");
    }
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      input,
      city,
      category,
      languageCode,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "generate_offer_draft_v2",
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
    return operation.value;
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
    const input = preprocessTranscript(request.data?.input ?? request.data?.hint);
    const city = cleanString(request.data?.city) || "";
    const category = cleanString(request.data?.category) || "";
    const languageCode = cleanString(request.data?.languageCode) || "fr-FR";
    if (!input) throw new HttpsError("invalid-argument", "INPUT_REQUIRED");
    if (input.length > MAX_TEXT_LENGTH) {
      throw new HttpsError("invalid-argument", "INPUT_TOO_LONG");
    }
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      input,
      city,
      category,
      languageCode,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "extract_listing_fields_v2",
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
    return operation.value;
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
    const languageCode = cleanString(request.data?.languageCode) || "fr-FR";
    const audio = await prepareUploadedAudio(uid, storagePath);
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      storagePath,
      audio.generation,
      languageCode,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "transcribe_listing_audio_v2",
      requestId,
      execute: async () => {
        const transcription = await transcribeAudio({
          audio,
          languageCode,
          requestId,
          operation: "transcribe_listing_audio",
        });
        return {
          transcription: buildTranscriptionPayload({
            ...transcription,
            languageCode,
            storagePath,
          }),
        };
      },
    });
    return operation.value;
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
    const city = cleanString(request.data?.city) || "";
    const category = cleanString(request.data?.category) || "";
    const languageCode = cleanString(request.data?.languageCode) || "fr-FR";
    const audio = await prepareUploadedAudio(uid, storagePath);
    const requestId = requestIdFrom(request.data?.clientRequestId, [
      storagePath,
      audio.generation,
      city,
      category,
      languageCode,
    ]);
    const operation = await runIdempotentOperation({
      uid,
      operation: "extract_listing_fields_from_audio_v2",
      requestId,
      execute: async () => {
        const transcription = await transcribeAudio({
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
        return {
          result,
          transcription: buildTranscriptionPayload({
            ...transcription,
            languageCode,
            storagePath,
          }),
        };
      },
    });
    return operation.value;
  },
);
