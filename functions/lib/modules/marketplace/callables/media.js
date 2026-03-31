"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.processOfferPhoto = void 0;
exports.processOfferPhotoStoragePath = processOfferPhotoStoragePath;
const node_crypto_1 = require("node:crypto");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const sharp_1 = __importDefault(require("sharp"));
const env_1 = require("../../../config/env");
const BRAND_WATERMARK_TEXT = "iliprestō";
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
function normalizeStoragePath(value) {
    return String(value ?? "").trim();
}
function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}
function buildBrandWatermarkSvg({ width, height, }) {
    const fontSize = clamp(Math.round(width * 0.05), 28, 72);
    const padX = clamp(Math.round(width * 0.03), 18, 42);
    const padY = clamp(Math.round(height * 0.02), 14, 30);
    const overlayWidth = Math.max(Math.round(width * 0.28), Math.round((fontSize * BRAND_WATERMARK_TEXT.length) * 0.78) + padX * 2);
    const overlayHeight = fontSize + padY * 2;
    const baselineY = overlayHeight - padY;
    return Buffer.from(`<svg width="${overlayWidth}" height="${overlayHeight}" xmlns="http://www.w3.org/2000/svg">
      <style>
        .t { font-family: Arial, sans-serif; font-size: ${fontSize}px; font-weight: 800; letter-spacing: 0.8px; }
      </style>
      <rect x="0" y="0" width="${overlayWidth}" height="${overlayHeight}" rx="18" ry="18" fill="#0f172a" fill-opacity="0.16"/>
      <text x="${overlayWidth - padX}" y="${baselineY}" text-anchor="end" class="t" fill="#0f172a" fill-opacity="0.34">${BRAND_WATERMARK_TEXT}</text>
      <text x="${overlayWidth - padX - 1}" y="${baselineY - 1}" text-anchor="end" class="t" fill="#ffffff" fill-opacity="0.82">${BRAND_WATERMARK_TEXT}</text>
    </svg>`);
}
async function processOfferPhotoStoragePath({ uid, storagePath, }) {
    const expectedPrefix = `offers_raw/${uid}/`;
    if (!storagePath.startsWith(expectedPrefix)) {
        throw new https_1.HttpsError("permission-denied", "Unauthorized storage path");
    }
    if (storagePath.includes("..") || storagePath.startsWith("/") || storagePath.includes("\\")) {
        throw new https_1.HttpsError("invalid-argument", "Invalid storage path");
    }
    const bucket = firebase_admin_1.default.storage().bucket();
    const srcFile = bucket.file(storagePath);
    let srcBuffer;
    try {
        const [buffer] = await srcFile.download();
        srcBuffer = buffer;
    }
    catch {
        throw new https_1.HttpsError("not-found", "Source photo not found");
    }
    let outputBuffer;
    let width = 0;
    let height = 0;
    try {
        const resized = await (0, sharp_1.default)(srcBuffer)
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
        const finalImage = await (0, sharp_1.default)(resized.data)
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
    }
    catch {
        throw new https_1.HttpsError("internal", "Image processing failed");
    }
    const baseDestPath = storagePath
        .replace(/^offers_raw\//, "offers/")
        .replace(/\.[^/.]+$/, "");
    const destPath = `${baseDestPath}.webp`;
    const token = (0, node_crypto_1.randomUUID)();
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
    }
    catch {
        throw new https_1.HttpsError("internal", "Image upload failed");
    }
    try {
        await srcFile.delete();
    }
    catch {
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
exports.processOfferPhoto = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    timeoutSeconds: 60,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const uid = requireAuthUid(request);
    const storagePath = normalizeStoragePath(request.data?.storagePath);
    if (!storagePath) {
        throw new https_1.HttpsError("invalid-argument", "storagePath is required");
    }
    return processOfferPhotoStoragePath({ uid, storagePath });
});
//# sourceMappingURL=media.js.map