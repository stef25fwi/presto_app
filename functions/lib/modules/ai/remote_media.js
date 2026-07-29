"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseExactStorageUrl = parseExactStorageUrl;
exports.downloadVerifiedRemoteImage = downloadVerifiedRemoteImage;
const https_1 = require("firebase-functions/v2/https");
const ALLOWED_IMAGE_MIME_TYPES = new Set([
    "image/jpeg",
    "image/png",
    "image/webp",
]);
function cleanBucket(value) {
    return value.trim().toLowerCase();
}
function parseExactStorageUrl(value, expectedBucket) {
    let parsed;
    try {
        parsed = new URL(value);
    }
    catch {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_URL_INVALID");
    }
    if (parsed.protocol !== "https:") {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_URL_NOT_ALLOWED");
    }
    const expected = cleanBucket(expectedBucket);
    let bucket = "";
    let objectPath = "";
    const segments = parsed.pathname.split("/").filter(Boolean);
    if (parsed.hostname === "firebasestorage.googleapis.com") {
        if (segments[0] !== "v0" || segments[1] !== "b" || segments[3] !== "o") {
            throw new https_1.HttpsError("invalid-argument", "IMAGE_URL_INVALID");
        }
        bucket = decodeURIComponent(segments[2] || "");
        objectPath = decodeURIComponent(segments.slice(4).join("/"));
    }
    else if (parsed.hostname === "storage.googleapis.com") {
        bucket = decodeURIComponent(segments[0] || "");
        objectPath = decodeURIComponent(segments.slice(1).join("/"));
    }
    else if (parsed.hostname.endsWith(".storage.googleapis.com")) {
        bucket = parsed.hostname.slice(0, -".storage.googleapis.com".length);
        objectPath = decodeURIComponent(segments.join("/"));
    }
    else {
        throw new https_1.HttpsError("invalid-argument", "IMAGE_URL_NOT_ALLOWED");
    }
    if (cleanBucket(bucket) !== expected || !objectPath || objectPath.includes("..")) {
        throw new https_1.HttpsError("permission-denied", "IMAGE_BUCKET_NOT_ALLOWED");
    }
    return { bucket, objectPath };
}
function normalizedMimeType(response) {
    return (response.headers.get("content-type") || "")
        .split(";", 1)[0]
        .trim()
        .toLowerCase();
}
async function downloadVerifiedRemoteImage(options) {
    const fetchImpl = options.fetchImpl || fetch;
    const maxRedirects = Math.max(0, Math.min(5, options.maxRedirects ?? 3));
    let currentUrl = options.url;
    for (let redirectCount = 0; redirectCount <= maxRedirects; redirectCount += 1) {
        const location = parseExactStorageUrl(currentUrl, options.expectedBucket);
        const response = await fetchImpl(currentUrl, {
            method: "GET",
            redirect: "manual",
            headers: { Accept: "image/jpeg,image/png,image/webp" },
            signal: AbortSignal.timeout(12_000),
        });
        if (response.status >= 300 && response.status < 400) {
            const next = response.headers.get("location");
            if (!next || redirectCount >= maxRedirects) {
                throw new https_1.HttpsError("failed-precondition", "IMAGE_REDIRECT_INVALID");
            }
            currentUrl = new URL(next, currentUrl).toString();
            parseExactStorageUrl(currentUrl, options.expectedBucket);
            continue;
        }
        if (!response.ok) {
            throw new https_1.HttpsError("not-found", "IMAGE_DOWNLOAD_FAILED");
        }
        const contentType = normalizedMimeType(response);
        if (!ALLOWED_IMAGE_MIME_TYPES.has(contentType)) {
            throw new https_1.HttpsError("invalid-argument", "IMAGE_TYPE_UNSUPPORTED");
        }
        const announcedSize = Number(response.headers.get("content-length") || 0);
        if (Number.isFinite(announcedSize) && announcedSize > options.maxBytes) {
            throw new https_1.HttpsError("invalid-argument", "IMAGE_TOO_LARGE");
        }
        const bytes = Buffer.from(await response.arrayBuffer());
        if (!bytes.length) {
            throw new https_1.HttpsError("invalid-argument", "IMAGE_EMPTY");
        }
        if (bytes.length > options.maxBytes) {
            throw new https_1.HttpsError("invalid-argument", "IMAGE_TOO_LARGE");
        }
        return {
            dataUrl: `data:${contentType};base64,${bytes.toString("base64")}`,
            contentType,
            sizeBytes: bytes.length,
            objectPath: location.objectPath,
        };
    }
    throw new https_1.HttpsError("failed-precondition", "IMAGE_REDIRECT_INVALID");
}
//# sourceMappingURL=remote_media.js.map