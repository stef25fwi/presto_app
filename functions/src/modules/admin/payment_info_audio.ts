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
  buildTtsTextHash,
  generateTtsMp3,
  resolveTtsConfig,
} from "../ai/tts_service";
import {
  extractRolesFromAuthToken,
  requireAnyRole,
} from "../marketplace/services/roles";

if (admin.apps.length === 0) admin.initializeApp();

const PUBLIC_CONFIG_DOC = "public_config/payment_info_audio";
const ADMIN_SETTINGS_DOC = "admin_settings/payment_info_audio";
const PUBLIC_STORAGE_PATH = "app_public/payment_audio/payment_info_current.mp3";
const DRAFT_STORAGE_PREFIX = "app_admin/payment_audio_drafts";

const DEFAULT_PAYMENT_TEXT = [
  "Bienvenue sur iliprestō.",
  "Cette fenêtre vous explique le fonctionnement du paiement.",
  "Vérifiez attentivement les informations affichées avant de confirmer.",
  "Si une option de paiement est disponible, suivez les étapes indiquées à l'écran.",
  "En cas de doute, vous pouvez revenir en arrière ou contacter l'assistance.",
].join(" ");

function cleanText(value: unknown): string {
  const text = typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
  return text.slice(0, 2_500);
}

function requireAdmin(request: {
  auth?: { uid?: string; token?: Record<string, unknown> } | null;
}): string {
  const uid = cleanText(request.auth?.uid);
  if (!uid) throw new HttpsError("unauthenticated", "AUTHENTICATION_REQUIRED");
  const roles = extractRolesFromAuthToken(request.auth?.token || {});
  requireAnyRole(roles, ["admin", "superadmin"], "Admin access required");
  return uid;
}

async function loadPaymentText(requestText: unknown): Promise<string> {
  const direct = cleanText(requestText);
  if (direct) return direct;
  const snapshot = await admin.firestore().doc(ADMIN_SETTINGS_DOC).get();
  const data = snapshot.data() || {};
  return (
    cleanText(data.text) ||
    cleanText(data.paymentText) ||
    cleanText(data.audioText) ||
    DEFAULT_PAYMENT_TEXT
  );
}

async function uploadMp3(options: {
  buffer: Buffer;
  uid: string;
  draft: boolean;
}): Promise<{
  audioUrl: string;
  storagePath: string;
  contentType: string;
  sizeBytes: number;
  version: number;
}> {
  const version = Date.now();
  const storagePath = options.draft
    ? `${DRAFT_STORAGE_PREFIX}/${options.uid}_${version}.mp3`
    : PUBLIC_STORAGE_PATH;
  const token = crypto.randomUUID();
  await admin
    .storage()
    .bucket()
    .file(storagePath)
    .save(options.buffer, {
      resumable: false,
      validation: "crc32c",
      metadata: {
        contentType: "audio/mpeg",
        cacheControl: "public, max-age=3600",
        metadata: {
          firebaseStorageDownloadTokens: token,
          generatedBy: options.uid,
          version: String(version),
          draft: options.draft ? "true" : "false",
        },
      },
    });
  const bucketName = admin.storage().bucket().name;
  const audioUrl =
    `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
    `${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
  return {
    audioUrl,
    storagePath,
    contentType: "audio/mpeg",
    sizeBytes: options.buffer.length,
    version,
  };
}

export const generatePaymentInfoAudio = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [OPENAI_API_KEY],
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = requireAdmin(request);
    const text = await loadPaymentText(request.data?.text);
    const config = resolveTtsConfig(request.data?.voice);
    const textHash = buildTtsTextHash(text, config);
    const publicRef = admin.firestore().doc(PUBLIC_CONFIG_DOC);
    const existing = (await publicRef.get()).data() || {};
    const existingUrl = cleanText(existing.audioUrl);
    if (existing.textHash === textHash && existingUrl) {
      logger.info("openai.tts.cache_hit", {
        model: config.model,
        voice: config.voice,
        storagePath: existing.storagePath || PUBLIC_STORAGE_PATH,
      });
      return { ok: true, ...existing, reused: true };
    }

    const generated = await generateTtsMp3({ text, config });
    const upload = await uploadMp3({ buffer: generated.buffer, uid, draft: false });
    const payload = {
      enabled: true,
      ...upload,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      generatedBy: uid,
      provider: "openai",
      model: config.model,
      voice: config.voice,
      textHash,
    };
    await publicRef.set(payload, { merge: true });
    await admin.firestore().doc(ADMIN_SETTINGS_DOC).set(
      {
        text,
        paymentText: text,
        audioText: text,
        lastGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPublishedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastGeneratedBy: uid,
        lastPublishedBy: uid,
        lastStoragePath: upload.storagePath,
        lastVersion: upload.version,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return {
      ok: true,
      ...payload,
      generatedAt: new Date().toISOString(),
      reused: false,
    };
  },
);

export const generatePaymentInfoAudioDraft = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [OPENAI_API_KEY],
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = requireAdmin(request);
    const text = await loadPaymentText(request.data?.text);
    if (!text) throw new HttpsError("invalid-argument", "AUDIO_TEXT_REQUIRED");
    const config = resolveTtsConfig(request.data?.voice);
    const textHash = buildTtsTextHash(text, config);
    const settingsRef = admin.firestore().doc(ADMIN_SETTINGS_DOC);
    const existing = (await settingsRef.get()).data() || {};
    const existingUrl = cleanText(existing.draftAudioUrl);
    if (existing.draftTextHash === textHash && existingUrl) {
      logger.info("openai.tts.draft_cache_hit", {
        model: config.model,
        voice: config.voice,
        storagePath: existing.draftStoragePath || null,
      });
      return { ok: true, ...existing, reused: true };
    }

    const generated = await generateTtsMp3({ text, config });
    const upload = await uploadMp3({ buffer: generated.buffer, uid, draft: true });
    const payload = {
      text,
      paymentText: text,
      audioText: text,
      draftAudioUrl: upload.audioUrl,
      draftStoragePath: upload.storagePath,
      draftContentType: upload.contentType,
      draftSizeBytes: upload.sizeBytes,
      draftVersion: upload.version,
      draftGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      draftGeneratedBy: uid,
      draftProvider: "openai",
      draftModel: config.model,
      draftVoice: config.voice,
      draftTextHash: textHash,
      lastGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastGeneratedBy: uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await settingsRef.set(payload, { merge: true });
    return {
      ok: true,
      ...payload,
      draftGeneratedAt: new Date().toISOString(),
      reused: false,
    };
  },
);

export const publishPaymentInfoAudioDraft = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request): Promise<Record<string, unknown>> => {
    const uid = requireAdmin(request);
    const db = admin.firestore();
    const settingsRef = db.doc(ADMIN_SETTINGS_DOC);
    const data = (await settingsRef.get()).data() || {};
    const audioUrl = cleanText(data.draftAudioUrl);
    const storagePath = cleanText(data.draftStoragePath);
    if (!audioUrl || !storagePath) {
      throw new HttpsError("failed-precondition", "AUDIO_DRAFT_REQUIRED");
    }
    const payload = {
      enabled: true,
      audioUrl,
      storagePath,
      contentType: cleanText(data.draftContentType) || "audio/mpeg",
      sizeBytes: Number(data.draftSizeBytes || 0) || null,
      version: Number(data.draftVersion || Date.now()),
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      generatedBy: uid,
      provider: "openai",
      model: cleanText(data.draftModel) || null,
      voice: cleanText(data.draftVoice) || null,
      textHash: cleanText(data.draftTextHash) || null,
    };
    await db.doc(PUBLIC_CONFIG_DOC).set(payload, { merge: true });
    await settingsRef.set(
      {
        lastPublishedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPublishedBy: uid,
        lastStoragePath: storagePath,
        lastVersion: payload.version,
      },
      { merge: true },
    );
    logger.info("openai.tts.draft_published", {
      uid,
      storagePath,
      version: payload.version,
    });
    return { ok: true, ...payload, generatedAt: new Date().toISOString() };
  },
);
