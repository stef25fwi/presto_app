"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminDeleteGeneratedVideo = exports.adminListGeneratedVideos = exports.adminGenerateVideo = void 0;
const node_crypto_1 = require("node:crypto");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firebase_functions_1 = require("firebase-functions");
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const roles_1 = require("../marketplace/services/roles");
const videomaker_utils_1 = require("./videomaker_utils");
const VEO_API_KEY = (0, params_1.defineSecret)("VEO_API_KEY");
const VEO_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";
const VIDEO_JOBS_COLLECTION = "_admin_video_maker_jobs";
const VIDEO_STORAGE_ROOT = "admin/videomaker/videos";
const MAX_POLL_ATTEMPTS = 51;
const POLL_INTERVAL_MS = 10_000;
class VeoHttpError extends Error {
    status;
    constructor(status, message) {
        super(message);
        this.status = status;
        this.name = "VeoHttpError";
    }
}
function asRecord(value) {
    return value != null && typeof value === "object" && !Array.isArray(value)
        ? value
        : {};
}
function requireAdmin(request) {
    const token = request.auth?.token;
    if (!token)
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    (0, roles_1.requireAnyRole)((0, roles_1.extractRolesFromAuthToken)(token), ["admin", "superadmin"], "Admin access required");
}
function messageFromUnknown(error) {
    if (error instanceof Error && error.message.trim()) {
        return error.message.trim().slice(0, 700);
    }
    return "Erreur inconnue pendant la génération VEO.";
}
function mapGenerationError(error) {
    if (error instanceof https_1.HttpsError)
        return error;
    if (error instanceof videomaker_utils_1.VideoMakerValidationError) {
        return new https_1.HttpsError("invalid-argument", error.message);
    }
    if (error instanceof VeoHttpError) {
        if (error.status === 400)
            return new https_1.HttpsError("invalid-argument", error.message);
        if (error.status === 401 || error.status === 403) {
            return new https_1.HttpsError("failed-precondition", "La clé API ne permet pas d’utiliser VEO. Vérifiez l’API Gemini, la facturation et les restrictions de clé.");
        }
        if (error.status === 429) {
            return new https_1.HttpsError("resource-exhausted", "Quota VEO atteint. Vérifiez les limites et la facturation de la clé API.");
        }
        if (error.status >= 500) {
            return new https_1.HttpsError("unavailable", "Le service VEO est temporairement indisponible.");
        }
    }
    if (messageFromUnknown(error).includes("VEO_TIMEOUT")) {
        return new https_1.HttpsError("deadline-exceeded", "VEO n’a pas terminé la vidéo dans le délai prévu.");
    }
    return new https_1.HttpsError("internal", "La génération VEO a échoué.");
}
async function readJsonResponse(response) {
    const body = await response.text();
    let parsed = {};
    if (body.trim()) {
        try {
            parsed = asRecord(JSON.parse(body));
        }
        catch {
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
function inlineImage(image) {
    return {
        inlineData: {
            mimeType: image.mimeType,
            data: image.base64,
        },
    };
}
async function startVeoGeneration(args) {
    const instance = { prompt: args.prompt };
    if (args.referenceImages.length === 1) {
        instance.image = inlineImage(args.referenceImages[0]);
    }
    else if (args.referenceImages.length > 1) {
        instance.referenceImages = args.referenceImages.map((image) => ({
            image: inlineImage(image),
            referenceType: "asset",
        }));
    }
    const response = await fetch(`${VEO_API_BASE_URL}/models/${encodeURIComponent(args.model)}:predictLongRunning`, {
        method: "POST",
        headers: {
            "content-type": "application/json",
            "x-goog-api-key": args.apiKey,
        },
        body: JSON.stringify({
            instances: [instance],
            parameters: {
                aspectRatio: args.aspectRatio,
                durationSeconds: args.referenceImages.length > 1 ? "8" : args.durationSeconds,
                resolution: args.resolution,
                numberOfVideos: 1,
                ...(args.referenceImages.length > 1 ? { personGeneration: "allow_adult" } : {}),
            },
        }),
    });
    const operation = await readJsonResponse(response);
    const operationName = typeof operation.name === "string" ? operation.name.trim() : "";
    if (!operationName)
        throw new Error("VEO_OPERATION_NAME_MISSING");
    return operationName;
}
function extractVideoUri(operation) {
    const response = asRecord(operation.response);
    const generateVideoResponse = asRecord(response.generateVideoResponse);
    const samples = Array.isArray(generateVideoResponse.generatedSamples)
        ? generateVideoResponse.generatedSamples
        : [];
    const sampleVideo = asRecord(asRecord(samples[0]).video);
    if (typeof sampleVideo.uri === "string" && sampleVideo.uri.trim()) {
        return sampleVideo.uri.trim();
    }
    const generatedVideos = Array.isArray(response.generatedVideos)
        ? response.generatedVideos
        : [];
    const generatedVideo = asRecord(asRecord(generatedVideos[0]).video);
    if (typeof generatedVideo.uri === "string" && generatedVideo.uri.trim()) {
        return generatedVideo.uri.trim();
    }
    throw new Error("VEO_VIDEO_URI_MISSING");
}
async function waitForVeoVideo(apiKey, operationName) {
    for (let attempt = 0; attempt < MAX_POLL_ATTEMPTS; attempt += 1) {
        if (attempt > 0)
            await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
        const response = await fetch(`${VEO_API_BASE_URL}/${operationName}`, {
            headers: { "x-goog-api-key": apiKey },
        });
        const operation = await readJsonResponse(response);
        if (operation.done !== true)
            continue;
        const operationError = asRecord(operation.error);
        if (Object.keys(operationError).length > 0) {
            throw new Error(typeof operationError.message === "string"
                ? operationError.message
                : "VEO a refusé la génération.");
        }
        return extractVideoUri(operation);
    }
    throw new Error("VEO_TIMEOUT");
}
async function downloadVeoVideo(apiKey, videoUri) {
    const response = await fetch(videoUri, {
        headers: { "x-goog-api-key": apiKey },
        redirect: "follow",
    });
    if (!response.ok) {
        throw new VeoHttpError(response.status, "Impossible de télécharger la vidéo générée.");
    }
    const bytes = Buffer.from(await response.arrayBuffer());
    if (bytes.length === 0)
        throw new Error("VEO_VIDEO_EMPTY");
    return bytes;
}
function firebaseDownloadUrl(bucketName, storagePath, token) {
    return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
        `${encodeURIComponent(storagePath)}?alt=media&token=${encodeURIComponent(token)}`;
}
function timestampToIso(value) {
    if (value instanceof firebase_admin_1.default.firestore.Timestamp)
        return value.toDate().toISOString();
    if (value instanceof Date)
        return value.toISOString();
    return null;
}
function serializeVideo(document) {
    const data = document.data();
    const imageNames = Array.isArray(data.referenceImageNames)
        ? data.referenceImageNames.filter((name) => typeof name === "string")
        : [];
    return {
        id: document.id,
        prompt: typeof data.prompt === "string" ? data.prompt : "",
        status: typeof data.status === "string" ? data.status : "processing",
        model: typeof data.model === "string" ? data.model : videomaker_utils_1.DEFAULT_VEO_MODEL,
        aspectRatio: typeof data.aspectRatio === "string" ? data.aspectRatio : "9:16",
        durationSeconds: typeof data.durationSeconds === "string" ? data.durationSeconds : "8",
        resolution: typeof data.resolution === "string" ? data.resolution : "720p",
        hasReferenceImage: data.hasReferenceImage === true,
        referenceImageCount: typeof data.referenceImageCount === "number"
            ? data.referenceImageCount
            : data.hasReferenceImage === true ? 1 : 0,
        referenceImageNames: imageNames,
        publicUrl: typeof data.publicUrl === "string" ? data.publicUrl : null,
        storagePath: typeof data.storagePath === "string" ? data.storagePath : null,
        fileName: typeof data.fileName === "string" ? data.fileName : null,
        sizeBytes: typeof data.sizeBytes === "number" ? data.sizeBytes : null,
        errorMessage: typeof data.errorMessage === "string" ? data.errorMessage : null,
        createdAt: timestampToIso(data.createdAt),
        generatedAt: timestampToIso(data.generatedAt),
    };
}
exports.adminGenerateVideo = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [VEO_API_KEY],
    timeoutSeconds: 540,
    memory: "1GiB",
}, async (request) => {
    requireAdmin(request);
    const input = asRecord(request.data);
    let prompt;
    let apiKey;
    let aspectRatio;
    let durationSeconds;
    let resolution;
    let referenceImages;
    try {
        prompt = (0, videomaker_utils_1.normalizeVideoPrompt)(input.prompt);
        apiKey = (0, videomaker_utils_1.normalizeApiKey)(input.apiKey, VEO_API_KEY.value());
        aspectRatio = (0, videomaker_utils_1.normalizeAspectRatio)(input.aspectRatio);
        durationSeconds = (0, videomaker_utils_1.normalizeDuration)(input.durationSeconds);
        resolution = (0, videomaker_utils_1.normalizeResolution)(input.resolution);
        referenceImages = (0, videomaker_utils_1.normalizeReferenceImages)(input.referenceImages, input.imageBase64, input.imageMimeType);
        if (referenceImages.length > 1)
            durationSeconds = "8";
    }
    catch (error) {
        throw mapGenerationError(error);
    }
    const model = videomaker_utils_1.DEFAULT_VEO_MODEL;
    const jobRef = (0, firestore_1.getDb)().collection(VIDEO_JOBS_COLLECTION).doc();
    const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
    await jobRef.set({
        status: "processing",
        prompt,
        model,
        aspectRatio,
        durationSeconds,
        resolution,
        hasReferenceImage: referenceImages.length > 0,
        referenceImageCount: referenceImages.length,
        referenceImageNames: referenceImages.map((image) => image.name).filter(Boolean),
        referenceImageBytes: referenceImages.reduce((sum, image) => sum + image.byteLength, 0),
        createdBy: request.auth?.uid ?? "unknown",
        createdAt: now,
        updatedAt: now,
        apiKeySource: typeof input.apiKey === "string" && input.apiKey.trim() ? "request" : "secret",
    });
    try {
        const operationName = await startVeoGeneration({
            apiKey,
            prompt,
            model,
            aspectRatio,
            durationSeconds,
            resolution,
            referenceImages,
        });
        await jobRef.update({
            operationName,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        const videoUri = await waitForVeoVideo(apiKey, operationName);
        const videoBytes = await downloadVeoVideo(apiKey, videoUri);
        const bucket = firebase_admin_1.default.storage().bucket();
        const storagePath = `${VIDEO_STORAGE_ROOT}/${jobRef.id}.mp4`;
        const downloadToken = (0, node_crypto_1.randomUUID)();
        await bucket.file(storagePath).save(videoBytes, {
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
            generatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            errorMessage: firebase_admin_1.default.firestore.FieldValue.delete(),
        });
        return { id: jobRef.id, status: "ready", publicUrl, fileName, model, aspectRatio };
    }
    catch (error) {
        const mappedError = mapGenerationError(error);
        firebase_functions_1.logger.error("adminGenerateVideo failed", {
            uid: request.auth?.uid ?? null,
            jobId: jobRef.id,
            referenceImageCount: referenceImages.length,
            error: messageFromUnknown(error),
        });
        await jobRef.update({
            status: "failed",
            errorMessage: mappedError.message,
            failedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        throw mappedError;
    }
});
exports.adminListGeneratedVideos = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    timeoutSeconds: 45,
    memory: "256MiB",
}, async (request) => {
    requireAdmin(request);
    const input = asRecord(request.data);
    const requestedLimit = Number(input.limit ?? 50);
    const limit = Number.isFinite(requestedLimit)
        ? Math.min(100, Math.max(1, Math.trunc(requestedLimit)))
        : 50;
    try {
        let snapshot;
        try {
            snapshot = await (0, firestore_1.getDb)()
                .collection(VIDEO_JOBS_COLLECTION)
                .orderBy("createdAt", "desc")
                .limit(limit)
                .get();
        }
        catch (orderedError) {
            firebase_functions_1.logger.warn("adminListGeneratedVideos ordered query fallback", {
                error: messageFromUnknown(orderedError),
            });
            snapshot = await (0, firestore_1.getDb)().collection(VIDEO_JOBS_COLLECTION).limit(limit).get();
        }
        const videos = snapshot.docs.map(serializeVideo).sort((left, right) => {
            return String(right.createdAt ?? "").localeCompare(String(left.createdAt ?? ""));
        });
        return { videos };
    }
    catch (error) {
        firebase_functions_1.logger.error("adminListGeneratedVideos failed", {
            uid: request.auth?.uid ?? null,
            limit,
            error: messageFromUnknown(error),
        });
        throw new https_1.HttpsError("unavailable", "Impossible de charger la bibliothèque de vidéos pour le moment.");
    }
});
exports.adminDeleteGeneratedVideo = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    timeoutSeconds: 45,
    memory: "256MiB",
}, async (request) => {
    requireAdmin(request);
    const id = typeof asRecord(request.data).id === "string"
        ? String(asRecord(request.data).id).trim()
        : "";
    if (!id || !/^[A-Za-z0-9_-]{6,128}$/.test(id)) {
        throw new https_1.HttpsError("invalid-argument", "Identifiant vidéo invalide.");
    }
    const ref = (0, firestore_1.getDb)().collection(VIDEO_JOBS_COLLECTION).doc(id);
    const snapshot = await ref.get();
    if (!snapshot.exists)
        throw new https_1.HttpsError("not-found", "Vidéo introuvable.");
    const data = snapshot.data() ?? {};
    const storagePath = typeof data.storagePath === "string" ? data.storagePath : "";
    try {
        if (storagePath) {
            await firebase_admin_1.default.storage().bucket().file(storagePath).delete({ ignoreNotFound: true });
        }
        await ref.delete();
        return { id, deleted: true };
    }
    catch (error) {
        firebase_functions_1.logger.error("adminDeleteGeneratedVideo failed", {
            uid: request.auth?.uid ?? null,
            id,
            storagePath,
            error: messageFromUnknown(error),
        });
        throw new https_1.HttpsError("internal", "Impossible de supprimer cette vidéo.");
    }
});
//# sourceMappingURL=videomaker.js.map