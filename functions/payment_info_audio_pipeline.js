const crypto = require("crypto");
const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

if (!admin.apps.length) {
  admin.initializeApp();
}

const { COST_POLICY } = require("./lib/config/cost_policy");
const { reserveMonthlyUsage } = require("./lib/shared/cost_quota");

const REGION = "europe-west1";
const PUBLIC_CONFIG_DOC = "public_config/payment_info_audio";
const ADMIN_SETTINGS_DOC = "admin_settings/payment_info_audio";
const STORAGE_PATH = "app_public/payment_audio/payment_info_current.mp3";
const DRAFT_STORAGE_PREFIX = "app_admin/payment_audio_drafts";
const OPENAI_API_KEY_SECRET = defineSecret("OPENAI_API_KEY");

const DEFAULT_PAYMENT_TEXT = [
  "Bienvenue sur ilipresto.",
  "Cette fenêtre vous explique le fonctionnement du paiement.",
  "Vérifiez attentivement les informations affichées avant de confirmer.",
  "Si une option de paiement est disponible, suivez les étapes indiquées à l'écran.",
  "En cas de doute, vous pouvez revenir en arrière ou contacter l'assistance.",
].join(" ");

function cleanText(value) {
  const text = String(value || "").replace(/\s+/g, " ").trim();

  if (!text) return "";
  if (text.length > 2500) return text.slice(0, 2500);

  return text;
}

function textHash(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function assertAdmin(request) {
  const uid = request.auth && request.auth.uid;
  const token = (request.auth && request.auth.token) || {};

  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }

  if (
    token.admin === true ||
    token.superAdmin === true ||
    token.role === "admin" ||
    token.role === "super_admin"
  ) {
    return uid;
  }

  const db = admin.firestore();

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() || {} : {};

  if (
    user.admin === true ||
    user.superAdmin === true ||
    user.role === "admin" ||
    user.role === "super_admin" ||
    (user.roles && (user.roles.admin === true || user.roles.superAdmin === true))
  ) {
    return uid;
  }

  const roleSnap = await db.doc(`user_roles/${uid}`).get();
  const role = roleSnap.exists ? roleSnap.data() || {} : {};

  if (
    role.admin === true ||
    role.superAdmin === true ||
    role.role === "admin" ||
    role.role === "super_admin"
  ) {
    return uid;
  }

  throw new HttpsError("permission-denied", "Accès administrateur requis.");
}

async function loadPaymentText(requestText) {
  const directText = cleanText(requestText);
  if (directText) return directText;

  const snap = await admin.firestore().doc(ADMIN_SETTINGS_DOC).get();
  const data = snap.exists ? snap.data() || {} : {};
  const firestoreText = cleanText(data.text || data.paymentText || data.audioText);

  return firestoreText || DEFAULT_PAYMENT_TEXT;
}

async function generateMp3BufferWithOpenAI(text, voice) {
  const apiKey =
    OPENAI_API_KEY_SECRET.value() ||
    process.env.OPENAI_API_KEY ||
    process.env.OPENAI_KEY ||
    process.env.OPENAI_SECRET;

  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "OPENAI_API_KEY absent côté Functions."
    );
  }

  const requestedModel = cleanText(process.env.OPENAI_TTS_MODEL) || "tts-1";
  const normalizedRequestedModel = requestedModel.toLowerCase();
  const modelCandidates =
    requestedModel === "tts-1"
      ? ["tts-1"]
      : normalizedRequestedModel.includes("nano")
          ? ["tts-1"]
          : [requestedModel, "tts-1"];
  const safeVoice = cleanText(voice) || process.env.OPENAI_TTS_VOICE || "nova";

  let lastStatus = 0;
  let lastBody = "";

  for (const model of modelCandidates) {
    for (let attempt = 1; attempt <= 4; attempt += 1) {
      await reserveMonthlyUsage({
        metric: "openai_requests",
        units: 1,
        limit: COST_POLICY.openAiMonthlyRequestLimit,
      });
      const response = await fetch("https://api.openai.com/v1/audio/speech", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          voice: safeVoice,
          input: text,
          response_format: "mp3",
        }),
      });

      if (response.ok) {
        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        if (!buffer.length) {
          throw new HttpsError("internal", "Le fichier audio généré est vide.");
        }

        return buffer;
      }

      lastStatus = response.status;
      lastBody = await response.text().catch(() => "");

      logger.error("OpenAI TTS failed", {
        status: lastStatus,
        attempt,
        model,
        voice: safeVoice,
        body: lastBody.slice(0, 700),
      });

      const bodyLower = lastBody.toLowerCase();
      const modelAccessDenied =
        response.status === 403 &&
        (bodyLower.includes("does not have access to model") ||
            bodyLower.includes("model_not_found") ||
            bodyLower.includes("unsupported_model"));
      if (modelAccessDenied) {
        // Switch to the next candidate model (typically tts-1) instead of failing hard.
        break;
      }

      if (response.status !== 429 || attempt === 4) {
        break;
      }

      await sleep(2500 * attempt);
    }
  }

  if (lastStatus === 429) {
    throw new HttpsError(
      "resource-exhausted",
      "OpenAI refuse temporairement la génération audio : limite de requêtes ou quota API atteint. Attends 1 à 2 minutes puis réessaie. Si l'erreur persiste, vérifie le budget/quota OpenAI API."
    );
  }

  throw new HttpsError(
    "internal",
    `Génération audio impossible. Statut TTS: ${lastStatus}`
  );
}

async function uploadMp3(buffer, uid, options = {}) {
  const bucket = admin.storage().bucket();
  const token = crypto.randomUUID();
  const version = Date.now();
  const isDraft = options.draft === true;

  const storagePath = isDraft
    ? `${DRAFT_STORAGE_PREFIX}/${uid}_${version}.mp3`
    : STORAGE_PATH;

  const file = bucket.file(storagePath);

  await file.save(buffer, {
    resumable: false,
    validation: false,
    metadata: {
      contentType: "audio/mpeg",
      cacheControl: "public, max-age=3600",
      metadata: {
        firebaseStorageDownloadTokens: token,
        generatedBy: uid,
        version: String(version),
        draft: isDraft ? "true" : "false",
      },
    },
  });

  const encodedPath = encodeURIComponent(storagePath);
  const audioUrl =
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}` +
    `?alt=media&token=${token}`;

  return {
    audioUrl,
    storagePath,
    version,
    contentType: "audio/mpeg",
    sizeBytes: buffer.length,
  };
}

exports.generatePaymentInfoAudio = onCall(
  {
    region: REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    cors: true,
    secrets: [OPENAI_API_KEY_SECRET],
  },
  async (request) => {
    const uid = await assertAdmin(request);
    const data = request.data || {};
    const text = await loadPaymentText(data.text);
    const voice = cleanText(data.voice) || "alloy";

    logger.info("Generating and publishing payment info audio", {
      uid,
      textLength: text.length,
      voice,
    });

    const mp3Buffer = await generateMp3BufferWithOpenAI(text, voice);
    const upload = await uploadMp3(mp3Buffer, uid, { draft: false });

    const payload = {
      enabled: true,
      audioUrl: upload.audioUrl,
      storagePath: upload.storagePath,
      contentType: upload.contentType,
      sizeBytes: upload.sizeBytes,
      version: upload.version,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      generatedBy: uid,
      provider: "openai",
      voice,
      textHash: textHash(text),
    };

    const db = admin.firestore();

    await db.doc(PUBLIC_CONFIG_DOC).set(payload, { merge: true });

    await db.doc(ADMIN_SETTINGS_DOC).set(
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
      },
      { merge: true }
    );

    return {
      ok: true,
      ...payload,
      generatedAt: new Date().toISOString(),
    };
  }
);

exports.generatePaymentInfoAudioDraft = onCall(
  {
    region: REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    cors: true,
    secrets: [OPENAI_API_KEY_SECRET],
  },
  async (request) => {
    const uid = await assertAdmin(request);
    const data = request.data || {};
    const text = await loadPaymentText(data.text);
    const voice = cleanText(data.voice) || "alloy";

    if (!text) {
      throw new HttpsError(
        "invalid-argument",
        "Le texte audio ne peut pas être vide."
      );
    }

    logger.info("Generating draft payment info audio", {
      uid,
      textLength: text.length,
      voice,
    });

    const mp3Buffer = await generateMp3BufferWithOpenAI(text, voice);
    const upload = await uploadMp3(mp3Buffer, uid, { draft: true });
    const hash = textHash(text);

    const draftPayload = {
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
      draftVoice: voice,
      draftTextHash: hash,
      lastGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastGeneratedBy: uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await admin.firestore().doc(ADMIN_SETTINGS_DOC).set(draftPayload, {
      merge: true,
    });

    return {
      ok: true,
      ...draftPayload,
      draftGeneratedAt: new Date().toISOString(),
    };
  }
);

exports.publishPaymentInfoAudioDraft = onCall(
  {
    region: REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
    cors: true,
  },
  async (request) => {
    const uid = await assertAdmin(request);
    const db = admin.firestore();

    const snap = await db.doc(ADMIN_SETTINGS_DOC).get();
    const data = snap.exists ? snap.data() || {} : {};

    const draftAudioUrl = cleanText(data.draftAudioUrl);
    const draftStoragePath = cleanText(data.draftStoragePath);
    const draftContentType = cleanText(data.draftContentType) || "audio/mpeg";
    const draftVersion =
      typeof data.draftVersion === "number" ? data.draftVersion : Date.now();
    const draftVoice = cleanText(data.draftVoice) || "alloy";
    const draftText = cleanText(data.text || data.paymentText || data.audioText);
    const draftTextHash = cleanText(data.draftTextHash) || textHash(draftText);

    if (!draftAudioUrl || !draftStoragePath) {
      throw new HttpsError(
        "failed-precondition",
        "Aucun brouillon MP3 disponible à publier."
      );
    }

    const payload = {
      enabled: true,
      audioUrl: draftAudioUrl,
      storagePath: draftStoragePath,
      contentType: draftContentType,
      sizeBytes: data.draftSizeBytes || null,
      version: draftVersion,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      generatedBy: uid,
      provider: "openai",
      voice: draftVoice,
      textHash: draftTextHash,
    };

    await db.doc(PUBLIC_CONFIG_DOC).set(payload, { merge: true });

    await db.doc(ADMIN_SETTINGS_DOC).set(
      {
        lastPublishedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPublishedBy: uid,
        lastStoragePath: draftStoragePath,
        lastVersion: draftVersion,
      },
      { merge: true }
    );

    logger.info("Published draft payment info audio", {
      uid,
      draftStoragePath,
      draftVersion,
    });

    return {
      ok: true,
      ...payload,
      generatedAt: new Date().toISOString(),
    };
  }
);
