import { HttpsError } from "firebase-functions/v2/https";

const ALLOWED_IMAGE_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

export interface VerifiedRemoteImage {
  dataUrl: string;
  contentType: string;
  sizeBytes: number;
  objectPath: string;
}

export interface StorageObjectLocation {
  bucket: string;
  objectPath: string;
}

function cleanBucket(value: string): string {
  return value.trim().toLowerCase();
}

export function parseExactStorageUrl(
  value: string,
  expectedBucket: string,
): StorageObjectLocation {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new HttpsError("invalid-argument", "IMAGE_URL_INVALID");
  }
  if (parsed.protocol !== "https:") {
    throw new HttpsError("invalid-argument", "IMAGE_URL_NOT_ALLOWED");
  }

  const expected = cleanBucket(expectedBucket);
  let bucket = "";
  let objectPath = "";
  const segments = parsed.pathname.split("/").filter(Boolean);

  if (parsed.hostname === "firebasestorage.googleapis.com") {
    if (segments[0] !== "v0" || segments[1] !== "b" || segments[3] !== "o") {
      throw new HttpsError("invalid-argument", "IMAGE_URL_INVALID");
    }
    bucket = decodeURIComponent(segments[2] || "");
    objectPath = decodeURIComponent(segments.slice(4).join("/"));
  } else if (parsed.hostname === "storage.googleapis.com") {
    bucket = decodeURIComponent(segments[0] || "");
    objectPath = decodeURIComponent(segments.slice(1).join("/"));
  } else if (parsed.hostname.endsWith(".storage.googleapis.com")) {
    bucket = parsed.hostname.slice(0, -".storage.googleapis.com".length);
    objectPath = decodeURIComponent(segments.join("/"));
  } else {
    throw new HttpsError("invalid-argument", "IMAGE_URL_NOT_ALLOWED");
  }

  if (cleanBucket(bucket) !== expected || !objectPath || objectPath.includes("..")) {
    throw new HttpsError("permission-denied", "IMAGE_BUCKET_NOT_ALLOWED");
  }
  return { bucket, objectPath };
}

function normalizedMimeType(response: Response): string {
  return (response.headers.get("content-type") || "")
    .split(";", 1)[0]!
    .trim()
    .toLowerCase();
}

export async function downloadVerifiedRemoteImage(options: {
  url: string;
  expectedBucket: string;
  maxBytes: number;
  fetchImpl?: typeof fetch;
  maxRedirects?: number;
}): Promise<VerifiedRemoteImage> {
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
        throw new HttpsError("failed-precondition", "IMAGE_REDIRECT_INVALID");
      }
      currentUrl = new URL(next, currentUrl).toString();
      parseExactStorageUrl(currentUrl, options.expectedBucket);
      continue;
    }
    if (!response.ok) {
      throw new HttpsError("not-found", "IMAGE_DOWNLOAD_FAILED");
    }

    const contentType = normalizedMimeType(response);
    if (!ALLOWED_IMAGE_MIME_TYPES.has(contentType)) {
      throw new HttpsError("invalid-argument", "IMAGE_TYPE_UNSUPPORTED");
    }
    const announcedSize = Number(response.headers.get("content-length") || 0);
    if (Number.isFinite(announcedSize) && announcedSize > options.maxBytes) {
      throw new HttpsError("invalid-argument", "IMAGE_TOO_LARGE");
    }

    const bytes = Buffer.from(await response.arrayBuffer());
    if (!bytes.length) {
      throw new HttpsError("invalid-argument", "IMAGE_EMPTY");
    }
    if (bytes.length > options.maxBytes) {
      throw new HttpsError("invalid-argument", "IMAGE_TOO_LARGE");
    }
    return {
      dataUrl: `data:${contentType};base64,${bytes.toString("base64")}`,
      contentType,
      sizeBytes: bytes.length,
      objectPath: location.objectPath,
    };
  }

  throw new HttpsError("failed-precondition", "IMAGE_REDIRECT_INVALID");
}
