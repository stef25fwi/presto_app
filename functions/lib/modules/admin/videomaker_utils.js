"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.VideoMakerValidationError = exports.MAX_REFERENCE_IMAGE_BYTES = exports.MAX_VIDEO_PROMPT_LENGTH = exports.DEFAULT_VIDEO_RESOLUTION = exports.DEFAULT_VIDEO_DURATION = exports.DEFAULT_VIDEO_ASPECT_RATIO = exports.DEFAULT_VEO_MODEL = void 0;
exports.normalizeVideoPrompt = normalizeVideoPrompt;
exports.normalizeAspectRatio = normalizeAspectRatio;
exports.normalizeDuration = normalizeDuration;
exports.normalizeResolution = normalizeResolution;
exports.normalizeReferenceImage = normalizeReferenceImage;
exports.normalizeApiKey = normalizeApiKey;
exports.DEFAULT_VEO_MODEL = "veo-3.1-generate-preview";
exports.DEFAULT_VIDEO_ASPECT_RATIO = "9:16";
exports.DEFAULT_VIDEO_DURATION = "8";
exports.DEFAULT_VIDEO_RESOLUTION = "720p";
exports.MAX_VIDEO_PROMPT_LENGTH = 4000;
exports.MAX_REFERENCE_IMAGE_BYTES = 5 * 1024 * 1024;
const SUPPORTED_ASPECT_RATIOS = new Set(["9:16", "16:9"]);
const SUPPORTED_DURATIONS = new Set(["4", "6", "8"]);
const SUPPORTED_RESOLUTIONS = new Set(["720p", "1080p", "4k"]);
const SUPPORTED_IMAGE_MIME_TYPES = new Set([
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
]);
class VideoMakerValidationError extends Error {
    constructor(message) {
        super(message);
        this.name = "VideoMakerValidationError";
    }
}
exports.VideoMakerValidationError = VideoMakerValidationError;
function normalizeVideoPrompt(value) {
    if (typeof value !== "string") {
        throw new VideoMakerValidationError("Le prompt est obligatoire.");
    }
    const prompt = value.trim();
    if (!prompt) {
        throw new VideoMakerValidationError("Le prompt est obligatoire.");
    }
    if (prompt.length > exports.MAX_VIDEO_PROMPT_LENGTH) {
        throw new VideoMakerValidationError(`Le prompt ne doit pas dépasser ${exports.MAX_VIDEO_PROMPT_LENGTH} caractères.`);
    }
    return prompt;
}
function normalizeAspectRatio(value) {
    const ratio = typeof value === "string" ? value.trim() : exports.DEFAULT_VIDEO_ASPECT_RATIO;
    if (!SUPPORTED_ASPECT_RATIOS.has(ratio)) {
        throw new VideoMakerValidationError("Le format doit être 9:16 ou 16:9.");
    }
    return ratio;
}
function normalizeDuration(value) {
    const duration = value == null ? exports.DEFAULT_VIDEO_DURATION : String(value).trim();
    if (!SUPPORTED_DURATIONS.has(duration)) {
        throw new VideoMakerValidationError("La durée doit être de 4, 6 ou 8 secondes.");
    }
    return duration;
}
function normalizeResolution(value) {
    const resolution = value == null ? exports.DEFAULT_VIDEO_RESOLUTION : String(value).trim();
    if (!SUPPORTED_RESOLUTIONS.has(resolution)) {
        throw new VideoMakerValidationError("La résolution doit être 720p, 1080p ou 4k.");
    }
    return resolution;
}
function normalizeReferenceImage(base64Value, mimeTypeValue) {
    const base64 = typeof base64Value === "string" ? base64Value.trim() : "";
    const mimeType = typeof mimeTypeValue === "string"
        ? mimeTypeValue.trim().toLowerCase()
        : "";
    if (!base64 && !mimeType)
        return null;
    if (!base64 || !mimeType) {
        throw new VideoMakerValidationError("L’image et son type MIME doivent être fournis ensemble.");
    }
    if (!SUPPORTED_IMAGE_MIME_TYPES.has(mimeType)) {
        throw new VideoMakerValidationError("Format d’image non pris en charge. Utilisez JPG, PNG, WEBP, HEIC ou HEIF.");
    }
    const bytes = Buffer.from(base64, "base64");
    if (bytes.length === 0) {
        throw new VideoMakerValidationError("L’image de référence est vide.");
    }
    if (bytes.length > exports.MAX_REFERENCE_IMAGE_BYTES) {
        throw new VideoMakerValidationError("L’image de référence doit peser moins de 5 Mo.");
    }
    return { base64, mimeType, byteLength: bytes.length };
}
function normalizeApiKey(value, fallback) {
    const supplied = typeof value === "string" ? value.trim() : "";
    const apiKey = supplied || fallback.trim();
    if (!apiKey) {
        throw new VideoMakerValidationError("Ajoutez une clé API Gemini ou configurez le secret VEO_API_KEY.");
    }
    if (apiKey.length > 512) {
        throw new VideoMakerValidationError("La clé API fournie est invalide.");
    }
    return apiKey;
}
//# sourceMappingURL=videomaker_utils.js.map