import crypto from "node:crypto";

import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  ENFORCE_APP_CHECK,
  OPENAI_API_KEY,
  PROJECT_REGION,
} from "../../config/env";
import { logger } from "../../core/logger";
import {
  classifyOpenAiError,
  getOpenAiClient,
} from "../ai/openai_runtime";
import { extractRolesFromAuthToken, requireAnyRole } from "../marketplace/services/roles";

const AUDIO_STORAGE_PATH = "audio/payment_info_popup_fr.mp3";
const PUBLIC_CONFIG_COLLECTION = "public_config";
const PAYMENT_INFO_AUDIO_DOC = "payment_info_audio";
const TTS_MODEL = process.env.OPENAI_TTS_MODEL?.trim() || "tts-1";
const TTS_VOICE = process.env.OPENAI_TTS_VOICE?.trim() || "nova";

const PAYMENT_INFO_NARRATION_FR = `Avant de payer une prestation sur iliprestō.

La législation prévoit des règles différentes selon le statut du prestataire et le type de prestation. Voici l'essentiel à retenir pour payer en toute sécurité.

Première règle : Prestation avec un professionnel. Le paiement doit pouvoir être justifié. Le prestataire peut remettre une facture ou un justificatif de paiement. Le paiement en espèces est limité à 1 000 euros lorsque le payeur a son domicile fiscal en France.

Deuxième règle : Prestation entre particuliers. Le paiement en espèces est possible lorsqu'il ne s'agit pas d'un besoin professionnel. Une preuve écrite est nécessaire au-delà de 1 500 euros.

Troisième règle : Services à la personne à domicile. Pour certaines activités comme le ménage, le jardinage, l'aide à la personne ou le soutien scolaire, le particulier peut utiliser le CESU. Le CESU permet de déclarer et rémunérer l'intervenant.

Quatrième règle : Pour plus de sécurité. Privilégiez toujours un paiement traçable pour protéger le client comme le prestataire en cas de litige. La carte bancaire, le virement, le paiement sécurisé ou un reçu écrit sont recommandés.

Les moyens de paiement acceptés sur iliprestō sont : la carte bancaire, le virement bancaire classique ou instantané, les espèces dans le cadre légal, le portefeuille électronique ou application mobile, le chèque, et le paiement sécurisé intégré iliprestō.

Important : ilipresto.fr est un outil de communication et de petites annonces. La plateforme facilite la visibilité des offres et demandes, mais les relations, accords et prestations restent exclusivement conclus et gérés entre les utilisateurs.`;

function buildTtsHash(text: string, model: string, voice: string): string {
  return crypto
    .createHash("sha256")
    .update(`${model}|${voice}|${text}`)
    .digest("hex");
}

function mapTtsError(error: unknown): HttpsError {
  const info = classifyOpenAiError(error);
  logger.error("openai.tts.failure", {
    model: TTS_MODEL,
    voice: TTS_VOICE,
    openAiRequestId: info.requestId,
    status: info.status,
    code: info.code,
    timeout: info.timeout,
    retryable: info.retryable,
    quotaExhausted: info.quotaExhausted,
  });
  if (info.timeout) {
    return new HttpsError("deadline-exceeded", "AI_TIMEOUT", {
      retryable: true,
    });
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
  return new HttpsError("internal", "AI_TTS_FAILED", {
    retryable: false,
  });
}

export const generatePaymentInfoAudio = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    const token = request.auth?.token as Record<string, unknown> | undefined;
    if (!token) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const roles = extractRolesFromAuthToken(token);
    requireAnyRole(roles, ["admin", "superadmin"], "Admin access required");

    const docRef = admin
      .firestore()
      .collection(PUBLIC_CONFIG_COLLECTION)
      .doc(PAYMENT_INFO_AUDIO_DOC);
    const textHash = buildTtsHash(
      PAYMENT_INFO_NARRATION_FR,
      TTS_MODEL,
      TTS_VOICE,
    );
    const existing = await docRef.get();
    const existingData = existing.data() || {};
    const existingUrl =
      typeof existingData.audioUrl === "string" ? existingData.audioUrl.trim() : "";
    if (existingData.textHash === textHash && existingUrl) {
      logger.info("openai.tts.cache_hit", {
        model: TTS_MODEL,
        voice: TTS_VOICE,
        storagePath: AUDIO_STORAGE_PATH,
      });
      return { audioUrl: existingUrl, reused: true };
    }

    const client = getOpenAiClient();
    const startedAtMs = Date.now();
    let response;
    try {
      response = await client.audio.speech.create(
        {
          model: TTS_MODEL,
          voice: TTS_VOICE,
          input: PAYMENT_INFO_NARRATION_FR,
          response_format: "mp3",
        },
        { timeout: 45_000, maxRetries: 1 },
      );
    } catch (error) {
      throw mapTtsError(error);
    }

    const arrayBuffer = await response.arrayBuffer();
    const mp3Buffer = Buffer.from(arrayBuffer);
    if (!mp3Buffer.length) {
      throw new HttpsError("internal", "AI_TTS_EMPTY", {
        retryable: false,
      });
    }

    const bucket = admin.storage().bucket();
    const file = bucket.file(AUDIO_STORAGE_PATH);
    await file.save(mp3Buffer, {
      resumable: false,
      metadata: {
        contentType: "audio/mpeg",
        cacheControl: "public, max-age=3600",
      },
    });
    await file.makePublic();
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${AUDIO_STORAGE_PATH}`;

    await docRef.set(
      {
        enabled: true,
        audioUrl: publicUrl,
        storagePath: AUDIO_STORAGE_PATH,
        fileName: "payment_info_popup_fr.mp3",
        contentType: "audio/mpeg",
        sizeBytes: mp3Buffer.length,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedBy: request.auth?.uid ?? "unknown",
        source: "tts_openai",
        model: TTS_MODEL,
        voice: TTS_VOICE,
        textHash,
      },
      { merge: true },
    );

    logger.info("openai.tts.success", {
      model: TTS_MODEL,
      voice: TTS_VOICE,
      durationMs: Date.now() - startedAtMs,
      sizeBytes: mp3Buffer.length,
      storagePath: AUDIO_STORAGE_PATH,
    });

    return { audioUrl: publicUrl, reused: false };
  },
);
