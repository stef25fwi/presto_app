const crypto = require("crypto");
const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

if (!admin.apps.length) {
  admin.initializeApp();
}

const REGION = "europe-west1";
const PUBLIC_CONFIG_DOC = "public_config/payment_info_audio";
const ADMIN_SETTINGS_DOC = "admin_settings/payment_info_audio";
const STORAGE_PATH = "app_public/payment_audio/payment_info_current.mp3";

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
    process.env.OPENAI_API_KEY ||
    process.env.OPENAI_KEY ||
    process.env.OPENAI_SECRET;

  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "OPENAI_API_KEY absent côté Functions."
    );
  }

  const model = process.env.OPENAI_TTS_MODEL || "gpt-4o-mini-tts";
  const safeVoice = cleanText(voice) || process.env.OPENAI_TTS_VOICE || "alloy";

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

  if (!response.ok) {
    const errorText = await response.text().catch(() => "");

    logger.error("OpenAI TTS failed", {
      status: response.status,
      body: errorText.slice(0, 500),
    });

    throw new HttpsError(
      "internal",
      `Génération audio impossible. Statut TTS: ${response.status}`
    );
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  if (!buffer.length) {
    throw new HttpsError("internal", "Le fichier audio généré est vide.");
  }

  return buffer;
}

async function uploadMp3(buffer, uid) {
  const bucket = admin.storage().bucket();
  const token = crypto.randomUUID();
  const version = Date.now();
  const file = bucket.file(STORAGE_PATH);

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
      },
    },
  });

  const encodedPath = encodeURIComponent(STORAGE_PATH);
  const audioUrl =
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}` +
    `?alt=media&token=${token}`;

  return {
    audioUrl,
    storagePath: STORAGE_PATH,
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
  },
  async (request) => {
    const uid = await assertAdmin(request);
    const data = request.data || {};
    const text = await loadPaymentText(data.text);
    const voice = cleanText(data.voice) || "alloy";

    logger.info("Generating payment info audio", {
      uid,
      textLength: text.length,
      voice,
    });

    const mp3Buffer = await generateMp3BufferWithOpenAI(text, voice);
    const upload = await uploadMp3(mp3Buffer, uid);

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
      textHash: crypto.createHash("sha256").update(text).digest("hex"),
    };

    const db = admin.firestore();

    await db.doc(PUBLIC_CONFIG_DOC).set(payload, { merge: true });

    await db.doc(ADMIN_SETTINGS_DOC).set(
      {
        lastGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastGeneratedBy: uid,
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
