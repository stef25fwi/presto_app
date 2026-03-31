import { randomUUID } from "node:crypto";

import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import sharp from "sharp";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";

const BRAND_WATERMARK_TEXT = "iliprestō";

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

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function buildBrandWatermarkSvg({
  width,
  height,
}: {
  width: number;
  height: number;
}): Buffer {
  const fontSize = clamp(Math.round(width * 0.05), 28, 72);
  const padX = clamp(Math.round(width * 0.03), 18, 42);
  const padY = clamp(Math.round(height * 0.02), 14, 30);
  const overlayWidth = Math.max(
    Math.round(width * 0.28),
    Math.round((fontSize * BRAND_WATERMARK_TEXT.length) * 0.78) + padX * 2,
  );
  const overlayHeight = fontSize + padY * 2;
  const baselineY = overlayHeight - padY;

  return Buffer.from(
    `<svg width="${overlayWidth}" height="${overlayHeight}" xmlns="http://www.w3.org/2000/svg">
      <style>
        .t { font-family: Arial, sans-serif; font-size: ${fontSize}px; font-weight: 800; letter-spacing: 0.8px; }
      </style>
      <rect x="0" y="0" width="${overlayWidth}" height="${overlayHeight}" rx="18" ry="18" fill="#0f172a" fill-opacity="0.16"/>
      <text x="${overlayWidth - padX}" y="${baselineY}" text-anchor="end" class="t" fill="#0f172a" fill-opacity="0.34">${BRAND_WATERMARK_TEXT}</text>
      <text x="${overlayWidth - padX - 1}" y="${baselineY - 1}" text-anchor="end" class="t" fill="#ffffff" fill-opacity="0.82">${BRAND_WATERMARK_TEXT}</text>
    </svg>`,
  );
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
    const watermarkInput = buildBrandWatermarkSvg({ width, height });

    const finalImage = await sharp(resized.data)
      .composite([
        {
          input: watermarkInput,
          gravity: "southeast",
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