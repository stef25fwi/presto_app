import { randomUUID } from "node:crypto";

import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import sharp from "sharp";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function normalizeStoragePath(value: unknown): string {
  return String(value ?? "").trim();
}

export interface ProcessedOfferPhotoResult {
  ok: true;
  storagePath: string;
  downloadUrl: string;
  thumbnailUrl: string;
  mimeType: "image/webp";
  width: number;
  height: number;
  sizeBytes: number;
}

export async function processOfferPhotoStoragePath({
  uid,
  storagePath,
}: {
  uid: string;
  storagePath: string;
}): Promise<ProcessedOfferPhotoResult> {
  const expectedPrefix = `offers_raw/${uid}/`;
  if (!storagePath.startsWith(expectedPrefix)) {
    throw new HttpsError("permission-denied", "Unauthorized storage path");
  }
  if (storagePath.includes("..") || storagePath.startsWith("/") || storagePath.includes("\\")) {
    throw new HttpsError("invalid-argument", "Invalid storage path");
  }

  const bucket = admin.storage().bucket();
  const srcFile = bucket.file(storagePath);

  let srcBuffer: Buffer;
  try {
    const [buffer] = await srcFile.download();
    srcBuffer = buffer;
  } catch {
    throw new HttpsError("not-found", "Source photo not found");
  }

  let outputBuffer: Buffer;
  let width = 0;
  let height = 0;

  try {
    const resized = await sharp(srcBuffer)
      .rotate()
      .resize({
        width: 1600,
        height: 1600,
        fit: "inside",
        withoutEnlargement: true,
      })
      .webp({ quality: 82, effort: 5 })
      .toBuffer({ resolveWithObject: true });

    width = resized.info.width ?? 1600;
    height = resized.info.height ?? 1200;

    const fontSize = Math.max(14, Math.min(28, Math.round(width * 0.022)));
    const padX = Math.max(10, Math.round(width * 0.02));
    const overlayHeight = Math.max(44, fontSize + 16);
    const safeUid = uid.replace(/[<>&"']/g, "");
    const watermarkText = `UID ${safeUid}`;
    const svg = Buffer.from(
      `<svg width="${width}" height="${overlayHeight}" xmlns="http://www.w3.org/2000/svg">
        <style>
          .t { font-family: Arial, sans-serif; font-size: ${fontSize}px; font-weight: 700; }
        </style>
        <rect x="0" y="0" width="${width}" height="${overlayHeight}" fill="transparent"/>
        <text x="${padX}" y="${Math.max(32, fontSize + 12)}" class="t" fill="#000000" fill-opacity="0.55">${watermarkText}</text>
        <text x="${padX}" y="${Math.max(31, fontSize + 11)}" class="t" fill="#FFFFFF" fill-opacity="0.70">${watermarkText}</text>
      </svg>`,
    );

    const finalImage = await sharp(resized.data)
      .composite([
        {
          input: svg,
          gravity: "southwest",
        },
      ])
      .webp({ quality: 82, effort: 5 })
      .toBuffer({ resolveWithObject: true });

    outputBuffer = finalImage.data;
    width = finalImage.info.width ?? width;
    height = finalImage.info.height ?? height;
  } catch {
    throw new HttpsError("internal", "Image processing failed");
  }

  const baseDestPath = storagePath
    .replace(/^offers_raw\//, "offers/")
    .replace(/\.[^/.]+$/, "");
  const destPath = `${baseDestPath}.webp`;
  const token = randomUUID();

  try {
    await bucket.file(destPath).save(outputBuffer, {
      contentType: "image/webp",
      resumable: false,
      metadata: {
        cacheControl: "public,max-age=31536000",
        metadata: {
          firebaseStorageDownloadTokens: token,
        },
      },
    });
  } catch {
    throw new HttpsError("internal", "Image upload failed");
  }

  try {
    await srcFile.delete();
  } catch {
    // best effort
  }

  const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destPath)}?alt=media&token=${token}`;

  return {
    ok: true,
    storagePath: destPath,
    downloadUrl,
    thumbnailUrl: downloadUrl,
    mimeType: "image/webp",
    width,
    height,
    sizeBytes: outputBuffer.length,
  };
}

export const processOfferPhoto = onCall(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 60,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },
  async (request) => {
    const uid = requireAuthUid(request);
    const storagePath = normalizeStoragePath(request.data?.storagePath);

    if (!storagePath) {
      throw new HttpsError("invalid-argument", "storagePath is required");
    }
    return processOfferPhotoStoragePath({ uid, storagePath });
  },
);