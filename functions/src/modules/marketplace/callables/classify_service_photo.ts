import admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import {
  OPENAI_API_KEY,
  ENFORCE_APP_CHECK,
  PROJECT_REGION,
} from "../../../config/env";
import { logger } from "../../../core/logger";
import {
  deriveClientRequestId,
  runIdempotentOperation,
} from "../../ai/idempotency";
import {
  classifyOpenAiError,
  getOpenAiClient,
  logOpenAiFailure,
  logOpenAiSuccess,
} from "../../ai/openai_runtime";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const MODEL = process.env.OPENAI_VISION_MODEL?.trim() || "gpt-4o-mini-2024-07-18";
const PROMPT_VERSION = "ilipresto-trade-photo-v2";
const SCHEMA_VERSION = "ilipresto-trade-photo-schema-v2";
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const ALLOWED_IMAGE_HOSTS = new Set([
  "firebasestorage.googleapis.com",
  "storage.googleapis.com",
]);

const VALID_TRADE_KEYS = [
  "serveur", "barman", "plongeur", "commis_cuisine", "cuisinier",
  "snack", "food_truck", "traiteur", "banquet",
  "plombier", "electricien", "montage_meubles", "luminaire", "etagere",
  "electromenager", "carreleur", "plaquiste", "portail", "installation_tv",
  "menage", "nettoyage_grand", "repassage", "courses", "cuisine_domicile",
  "aide_personne_agee", "aide_administrative", "gardiennage",
  "nettoyage_demenagement", "rangement",
  "baby_sitter", "sortie_ecole", "garde_periscolaire", "garde_weekend",
  "garde_vacances", "garde_domicile",
  "dj", "dj_mariage", "sono", "animateur", "photographe", "videaste",
  "decoration_salle", "organisation_evenement",
  "soutien_primaire", "soutien_college", "soutien_lycee", "maths_physique",
  "francais_langues", "anglais", "espagnol", "informatique_cours",
  "musique", "coaching_sport", "concours",
  "tonte", "taille_haies", "debroussaillage", "desherbage", "elagage",
  "plantation", "potager",
  "peintre", "peinture_facade", "peinture_portail", "enduit",
  "renovation_locative",
  "demenageur", "manutention", "vigile", "distribution_flyers",
  "inventaire", "debarras", "stand",
  "informatique_depannage", "reseaux_sociaux", "nettoyage_vehicule",
  "coaching_perso", "traduction", "pet_sitting", "couture", "shooting_photo",
] as const;

const VALID_TRADE_KEY_SET = new Set<string>(VALID_TRADE_KEYS);

const RESPONSE_FORMAT = {
  type: "json_schema",
  json_schema: {
    name: "ilipresto_trade_photo_result",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        metier: {
          anyOf: [
            { type: "string", enum: [...VALID_TRADE_KEYS] },
            { type: "null" },
          ],
        },
        confidence: { type: "number", minimum: 0, maximum: 1 },
      },
      required: ["metier", "confidence"],
    },
  },
} as const;

const SYSTEM_PROMPT = `Tu es un classificateur de services pour iliprestō.
Analyse l'image et identifie uniquement le métier ou service principal visible.
Utilise exclusivement la clé autorisée par le schéma.
Si aucun métier n'est suffisamment reconnaissable, renvoie metier=null et confidence=0.
N'invente pas de contexte absent de l'image.`;

export interface ClassifyServicePhotoResult extends Record<string, unknown> {
  metier: string | null;
  confidence: number;
}

function normalizeMimeType(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function validateImageUrl(value: string): string {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new HttpsError("invalid-argument", "IMAGE_URL_INVALID");
  }
  if (parsed.protocol !== "https:" || !ALLOWED_IMAGE_HOSTS.has(parsed.hostname)) {
    throw new HttpsError("invalid-argument", "IMAGE_URL_NOT_ALLOWED");
  }
  return parsed.toString();
}

function validateBase64(value: string, mimeType: string): string {
  if (!ALLOWED_MIME_TYPES.has(mimeType)) {
    throw new HttpsError("invalid-argument", "IMAGE_TYPE_UNSUPPORTED");
  }
  const normalized = value.replace(/\s+/g, "");
  const estimatedBytes = Math.floor((normalized.length * 3) / 4);
  if (!normalized || estimatedBytes <= 0) {
    throw new HttpsError("invalid-argument", "IMAGE_EMPTY");
  }
  if (estimatedBytes > MAX_IMAGE_BYTES) {
    throw new HttpsError("invalid-argument", "IMAGE_TOO_LARGE");
  }
  return normalized;
}

async function enforceRateLimit(uid: string): Promise<void> {
  const now = Date.now();
  const windowSeconds = 60;
  const bucket = Math.floor(now / (windowSeconds * 1000));
  const ref = admin
    .firestore()
    .collection("_rate_limits")
    .doc(`classify_service_photo_${uid}_${bucket}`);
  await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const previous = snapshot.exists ? Number(snapshot.data()?.count || 0) : 0;
    const next = previous + 1;
    if (next > 10) {
      throw new HttpsError("resource-exhausted", "AI_RATE_LIMITED", {
        retryable: true,
      });
    }
    transaction.set(
      ref,
      {
        uid,
        action: "classify_service_photo",
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

function mapProviderError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  const info = classifyOpenAiError(error);
  if (info.timeout) {
    return new HttpsError("deadline-exceeded", "AI_TIMEOUT", {
      retryable: true,
    });
  }
  if (info.status === 429) {
    return new HttpsError("resource-exhausted", "AI_RATE_LIMITED", {
      retryable: !info.quotaExhausted,
    });
  }
  if (info.retryable) {
    return new HttpsError("unavailable", "AI_PROVIDER_UNAVAILABLE", {
      retryable: true,
    });
  }
  return new HttpsError("internal", "AI_PROVIDER_ERROR", {
    retryable: false,
  });
}

export const classifyServicePhoto = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request): Promise<ClassifyServicePhotoResult> => {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
      throw new HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
    }
    await enforceRateLimit(uid);

    const imageUrl =
      typeof request.data?.imageUrl === "string" && request.data.imageUrl.trim()
        ? validateImageUrl(request.data.imageUrl.trim())
        : null;
    const rawBase64 =
      typeof request.data?.imageBase64 === "string"
        ? request.data.imageBase64
        : "";
    const mimeType = normalizeMimeType(request.data?.mimeType) || "image/jpeg";
    const imageBase64 = rawBase64 ? validateBase64(rawBase64, mimeType) : null;

    if (!imageUrl && !imageBase64) {
      throw new HttpsError("invalid-argument", "IMAGE_REQUIRED");
    }

    const requestId = deriveClientRequestId([
      imageUrl || "inline",
      imageBase64 || "",
      mimeType,
      MODEL,
      PROMPT_VERSION,
    ]);

    const operation = await runIdempotentOperation<ClassifyServicePhotoResult>({
      uid,
      operation: "classify_service_photo_v2",
      requestId,
      ttlMs: 7 * 24 * 60 * 60 * 1000,
      execute: async () => {
        const client = getOpenAiClient();
        const startedAtMs = Date.now();
        const context = {
          operation: "classify_service_photo",
          requestId,
          model: MODEL,
          promptVersion: PROMPT_VERSION,
          schemaVersion: SCHEMA_VERSION,
          startedAtMs,
        };

        try {
          const response = await client.chat.completions.create(
            {
              model: MODEL,
              max_tokens: 64,
              temperature: 0,
              response_format: RESPONSE_FORMAT as never,
              messages: [
                { role: "system", content: SYSTEM_PROMPT },
                {
                  role: "user",
                  content: [
                    {
                      type: "image_url",
                      image_url: {
                        url: imageUrl || `data:${mimeType};base64,${imageBase64}`,
                        detail: "low",
                      },
                    },
                  ],
                },
              ],
            },
            { timeout: 15_000, maxRetries: 1 },
          );
          logOpenAiSuccess(context, response);

          const content = response.choices[0]?.message?.content?.trim() || "";
          if (!content) {
            throw new HttpsError("internal", "AI_OUTPUT_EMPTY", {
              retryable: true,
            });
          }
          const parsed = JSON.parse(content) as {
            metier: unknown;
            confidence: unknown;
          };
          const metier =
            typeof parsed.metier === "string" &&
            VALID_TRADE_KEY_SET.has(parsed.metier)
              ? parsed.metier
              : null;
          const rawConfidence = Number(parsed.confidence);
          const confidence = Number.isFinite(rawConfidence)
            ? Math.max(0, Math.min(1, rawConfidence))
            : 0;
          logger.info("classifyServicePhoto", {
            uid,
            metier,
            confidence,
            cacheHit: false,
          });
          return { metier, confidence };
        } catch (error) {
          if (!(error instanceof HttpsError)) {
            logOpenAiFailure(context, error);
          }
          throw mapProviderError(error);
        }
      },
    });

    return operation.value;
  },
);
