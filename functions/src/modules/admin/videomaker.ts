import { randomUUID } from "node:crypto";

import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION, VEO_API_KEY } from "../../config/env";
import { getDb } from "../../core/firestore";
import { extractRolesFromAuthToken, requireAnyRole } from "../marketplace/services/roles";
import {
  DEFAULT_VEO_MODEL,
  VideoMakerValidationError,
  normalizeApiKey,
  normalizeAspectRatio,
  normalizeDuration,
  normalizeReferenceImage,
  normalizeResolution,
  normalizeVideoPrompt,
} from "./videomaker_utils";

const VEO_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";
const VIDEO_JOBS_COLLECTION = "_admin_video_maker_jobs";
const VIDEO_STORAGE_ROOT = "admin/videomaker/videos";
const MAX_POLL_ATTEMPTS = 51;
const POLL_INTERVAL_MS = 10_000;

type JsonRecord = Record<string, unknown>;

class VeoHttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "VeoHttpError";
  }
}

function asRecord(value: unknown): JsonRecord {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function requireAdmin(request: { auth?: { token?: unknown } | null }): void {
  const token = request.auth?.token as Record<string, unknown> | undefined;
  if (!token) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }
  const roles = extractRolesFromAuthToken(token);
  requireAnyRole(roles, ["admin", "superadmin"], "Admin access required");
}

function messageFromUnknown(error: unknown): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message.trim().slice(0, 700);
  }
  return "Erreur inconnue pendant la génération VEO.";
}

function mapGenerationError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  if (error instanceof VideoMakerValidationError) {
    return new HttpsError("invalid-argument", error.message);
  }
  if (error instanceof VeoHttpError) {
    if (error.status === 400) {
      return new HttpsError("invalid-argument", error.message);
    }
    if (error.status === 401 || error.status === 403) {
      return new HttpsError(
        "failed-precondition",
        "La clé API ne permet pas d’utiliser VEO. Vérifiez l’API Gemini, la facturation et les restrictions de clé.",
      );
    }
    if (error.status === 429) {
      return new HttpsError(
        "resource-exhausted",
        "Quota VEO atteint. Vérifiez les limites et la facturation de la clé API.",
      );
    }
    if (error.status >= 500) {
      return new HttpsError(
        "unavailable",
        "Le service VEO est temporairement indisponible.",
      );
    }
  }
  if (messageFromUnknown(error).includes("VEO_TIMEOUT")) {
    return new HttpsError(
      "deadline-exceeded",
      "VEO n’a pas terminé la vidéo dans le délai prévu.",
    );
  }
  return new HttpsError("internal", "La génération VEO a échoué.");
}

async function readJsonResponse(response: Response): Promise<JsonRecord> {
  const body = await response.text();
  let parsed: JsonRecord = {};
  if (body.trim()) {
    try {
      parsed = asRecord(JSON.parse(body));
    } catch {
      parsed = {};
    }
  }
  if (!response.ok) {
    const apiError = asRecord(parsed.error);
    const apiMessage = typeof apiError.message === "string"
      ? apiError.message.trim()
      : `Erreur VEO HTTP ${response.status}`;
    throw new VeoHttpError(response.status, apiMessage.slice(0, 700));
  }
  return parsed;
}

async function startVeoGeneration(args: {
  apiKey: string;
  prompt: string;
  model: string;
  aspectRatio: "9:16" | "16:9";
  durationSeconds: "4" | "6" | "8";
  resolution: "720p" | "1080p" | "4k";
  referenceImage: ReturnType<typeof normalizeReferenceImage>;
}): Promise<string> {
  const instance: JsonRecord = { prompt: args.prompt };
  if (args.referenceImage) {
    instance.image = {
      inlineData: {
        mimeType: args.referenceImage.mimeType,
        data: args.referenceImage.base64,
      },
    };
  }

  const response = await fetch(
    `${VEO_API_BASE_URL}/models/${encodeURIComponent(args.model)}:predictLongRunning`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": args.apiKey,
      },
      body: JSON.stringify({
        instances: [instance],
        parameters: {
          aspectRatio: args.aspectRatio,
          durationSeconds: args.durationSeconds,
          resolution: args.resolution,
          numberOfVideos: 1,
        },
      }),
    },
  );

  const operation = await readJsonResponse(response);
  const operationName = typeof operation.name === "string" ? operation.name.trim() : "";
  if (!operationName) {
    throw new Error("VEO_OPERATION_NAME_MISSING");
  }
  return operationName;
}

function extractVideoUri(operation: JsonRecord): string {
  const response = asRecord(operation.response);
  const generateVideoResponse = asRecord(response.generateVideoResponse);
  const samples = Array.isArray(generateVideoResponse.generatedSamples)
    ? generateVideoResponse.generatedSamples
    : [];
  const firstSample = asRecord(samples[0]);
  const sampleVideo = asRecord(firstSample.video);
  if (typeof sampleVideo.uri === "string" && sampleVideo.uri.trim()) {
    return sampleVideo.uri.trim();
  }

  const generatedVideos = Array.isArray(response.generatedVideos)
    ? response.generatedVideos
    : [];
  const firstGenerated = asRecord(generatedVideos[0]);
  const generatedVideo = asRecord(firstGenerated.video);
  if (typeof generatedVideo.uri === "string" && generatedVideo.uri.trim()) {
    return generatedVideo.uri.trim();
  }

  throw new Error("VEO_VIDEO_URI_MISSING");
}

async function waitForVeoVideo(apiKey: string, operationName: string): Promise<string> {
  for (let attempt = 0; attempt < MAX_POLL_ATTEMPTS; attempt += 1) {
    if (attempt > 0) {
      await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
    }
    const response = await fetch(`${VEO_API_BASE_URL}/${operationName}`, {
      headers: { "x-goog-api-key": apiKey },
    });
    const operation = await readJsonResponse(response);
    if (operation.done !== true) continue;

    const operationError = asRecord(operation.error);
    if (Object.keys(operationError).length > 0) {
      const message = typeof operationError.message === "string"
        ? operationError.message
        : "VEO a refusé la génération.";
      throw new Error(message);
    }
    return extractVideoUri(operation);
  }
  throw new Error("VEO_TIMEOUT");
}

async function downloadVeoVideo(apiKey: string, videoUri: string): Promise<Buffer> {
  const response = await fetch(videoUri, {
    headers: { "x-goog-api-key": apiKey },
    redirect: "follow",
  });
  if (!response.ok) {
    throw new VeoHttpError(response.status, "Impossible de télécharger la vidéo générée.");
  }
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length === 0) {
    throw new Error("VEO_VIDEO_EMPTY");
  }
  return bytes;
}

function firebaseDownloadUrl(bucketName: string, storagePath: string, token: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
    `${encodeURIComponent(storagePath)}?alt=media&token=${encodeURIComponent(token)}`;
}

function timestampToIso(value: unknown): string | null {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) return value.toISOString();
  return null;
}

export const adminGenerateVideo = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [VEO_API_KEY],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    requireAdmin(request);
    const input = asRecord(request.data);

    let prompt: string;
    let apiKey: string;
    let aspectRatio: "9:16" | "16:9";
    let durationSeconds: "4" | "6" | "8";
    let resolution: "720p" | "1080p" | "4k";
    let referenceImage: ReturnType<typeof normalizeReferenceImage>;
    try {
      prompt = normalizeVideoPrompt(input.prompt);
      apiKey = normalizeApiKey(input.apiKey, VEO_API_KEY.value());
      aspectRatio = normalizeAspectRatio(input.aspectRatio);
      durationSeconds = normalizeDuration(input.durationSeconds);
      resolution = normalizeResolution(input.resolution);
      referenceImage = normalizeReferenceImage(input.imageBase64, input.imageMimeType);
    } catch (error) {
      throw mapGenerationError(error);
    }

    const model = DEFAULT_VEO_MODEL;
    const db = getDb();
    const jobRef = db.collection(VIDEO_JOBS_COLLECTION).doc();
    const now = admin.firestore.FieldValue.serverTimestamp();
    await jobRef.set({
      status: "processing",
      prompt,
      model,
      aspectRatio,
      durationSeconds,
      resolution,
      hasReferenceImage: referenceImage != null,
      referenceImageBytes: referenceImage?.byteLength ?? 0,
      createdBy: request.auth?.uid ?? "unknown",
      createdAt: now,
      updatedAt: now,
      apiKeySource:
        typeof input.apiKey === "string" && input.apiKey.trim() ? "request" : "secret",
    });

    try {
      const operationName = await startVeoGeneration({
        apiKey,
        prompt,
        model,
        aspectRatio,
        durationSeconds,
        resolution,
        referenceImage,
      });
      await jobRef.update({
        operationName,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const videoUri = await waitForVeoVideo(apiKey, operationName);
      const videoBytes = await downloadVeoVideo(apiKey, videoUri);

      const bucket = admin.storage().bucket();
      const storagePath = `${VIDEO_STORAGE_ROOT}/${jobRef.id}.mp4`;
      const downloadToken = randomUUID();
      const file = bucket.file(storagePath);
      await file.save(videoBytes, {
        resumable: false,
        metadata: {
          contentType: "video/mp4",
          cacheControl: "public,max-age=3600",
          metadata: {
            firebaseStorageDownloadTokens: downloadToken,
            generatedBy: request.auth?.uid ?? "unknown",
            generator: model,
          },
        },
      });

      const publicUrl = firebaseDownloadUrl(bucket.name, storagePath, downloadToken);
      const fileName = `veo-${jobRef.id}.mp4`;
      await jobRef.update({
        status: "ready",
        storagePath,
        publicUrl,
        fileName,
        sizeBytes: videoBytes.length,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        errorMessage: admin.firestore.FieldValue.delete(),
      });

      return {
        id: jobRef.id,
        status: "ready",
        publicUrl,
        fileName,
        model,
        aspectRatio,
      };
    } catch (error) {
      const mappedError = mapGenerationError(error);
      await jobRef.update({
        status: "failed",
        errorMessage: mappedError.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw mappedError;
    }
  },
);

export const adminListGeneratedVideos = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    timeoutSeconds: 45,
    memory: "256MiB",
  },
  async (request) => {
    requireAdmin(request);
    const input = asRecord(request.data);
    const requestedLimit = Number(input.limit ?? 50);
    const limit = Number.isFinite(requestedLimit)
      ? Math.min(50, Math.max(1, Math.trunc(requestedLimit)))
      : 50;

    const snapshot = await getDb()
      .collection(VIDEO_JOBS_COLLECTION)
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    return {
      videos: snapshot.docs.map((document) => {
        const data = document.data();
        return {
          id: document.id,
          prompt: typeof data.prompt === "string" ? data.prompt : "",
          status: typeof data.status === "string" ? data.status : "processing",
          model: typeof data.model === "string" ? data.model : DEFAULT_VEO_MODEL,
          aspectRatio:
            typeof data.aspectRatio === "string" ? data.aspectRatio : "9:16",
          durationSeconds:
            typeof data.durationSeconds === "string" ? data.durationSeconds : "8",
          resolution: typeof data.resolution === "string" ? data.resolution : "720p",
          hasReferenceImage: data.hasReferenceImage === true,
          publicUrl: typeof data.publicUrl === "string" ? data.publicUrl : null,
          fileName: typeof data.fileName === "string" ? data.fileName : null,
          sizeBytes: typeof data.sizeBytes === "number" ? data.sizeBytes : null,
          errorMessage:
            typeof data.errorMessage === "string" ? data.errorMessage : null,
          createdAt: timestampToIso(data.createdAt),
          generatedAt: timestampToIso(data.generatedAt),
        };
      }),
    };
  },
);
