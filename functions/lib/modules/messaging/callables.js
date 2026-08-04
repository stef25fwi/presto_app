"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteConversationMessage = exports.deleteConversation = exports.adminUnblockConversation = exports.unblockConversation = exports.blockConversation = exports.unarchiveConversation = exports.archiveConversation = exports.markConversationRead = exports.sendConversationMessage = exports.ensureOfferConversation = exports.processConversationAttachmentPhoto = void 0;
exports.assertConversationParticipantAccess = assertConversationParticipantAccess;
exports.canonicalConversationId = canonicalConversationId;
exports.shouldForkConversationThread = shouldForkConversationThread;
exports.resolveOfferLikeData = resolveOfferLikeData;
exports.getMessagingAttachmentEntitlements = getMessagingAttachmentEntitlements;
exports.buildAttachmentMessageFallbackText = buildAttachmentMessageFallbackText;
exports.buildProcessedConversationAttachmentPath = buildProcessedConversationAttachmentPath;
exports.sanitizeConversationAttachments = sanitizeConversationAttachments;
exports.mergeConversationParticipants = mergeConversationParticipants;
exports.computeUnreadCountAfterMessageDeletion = computeUnreadCountAfterMessageDeletion;
const node_crypto_1 = require("node:crypto");
const node_path_1 = require("node:path");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const sharp_1 = __importDefault(require("sharp"));
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const logger_1 = require("../../core/logger");
const rate_limit_1 = require("../../core/rate_limit");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
const admin_audit_1 = require("../marketplace/services/admin_audit");
const roles_1 = require("../marketplace/services/roles");
const counters_1 = require("../notifications/counters");
const moderation_1 = require("./moderation");
const state_1 = require("./state");
const participants_1 = require("./participants");
const mirror_1 = require("./mirror");
const MESSAGE_SEND_WINDOW_MS = 10 * 1000;
const MESSAGE_SEND_LIMIT = 6;
const DUPLICATE_MESSAGE_WINDOW_MS = 15 * 1000;
const CONVERSATION_IMAGE_MAX_EDGE = 960;
// Messaging is protected by Firebase Auth, participant checks, strict input
// validation and rate limits. Keeping App Check non-blocking here prevents a
// broken/rotating web reCAPTCHA domain from taking the whole inbox offline.
const MESSAGING_CALLABLE_OPTIONS = {
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
};
// Chemin chaud de la messagerie : on garde 1 instance au chaud pour éliminer
// le cold start (sinon le 1er message après inactivité met ~2-5 s à partir).
// Appliqué uniquement aux callables critiques (envoi + marquage lu) pour
// limiter le coût (1 instance toujours active par fonction).
const HOT_MESSAGING_CALLABLE_OPTIONS = {
    ...MESSAGING_CALLABLE_OPTIONS,
    minInstances: 1,
};
async function findConversationSnapshotsForParticipant(currentUserId, listingId) {
    const conversationCollection = firestore_1.db.collection(constants_1.COLLECTIONS.conversations);
    const listingFieldAliases = listingId ? ["listingId", "offerId", "offer_id"] : [null];
    const snapshots = await Promise.all(participants_1.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.flatMap((participantField) => listingFieldAliases.map((listingField) => {
        let query = conversationCollection.where(participantField, "array-contains", currentUserId);
        if (listingId && listingField) {
            query = query.where(listingField, "==", listingId);
        }
        return query.limit(20).get();
    })));
    const deduped = new Map();
    for (const snapshot of snapshots) {
        for (const doc of snapshot.docs) {
            deduped.set(doc.id, doc);
        }
    }
    return [...deduped.values()];
}
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    return uid;
}
function hasAdminAccessFromRequest(request) {
    const token = request.auth?.token;
    const roles = (0, roles_1.extractRolesFromAuthToken)(token);
    const primaryRole = String(token?.primaryRole || token?.role || token?.adminRole || "")
        .trim()
        .toLowerCase();
    return (roles.includes("admin") ||
        roles.includes("superadmin") ||
        primaryRole === "admin" ||
        primaryRole === "superadmin" ||
        token?.admin === true ||
        token?.isAdmin === true ||
        token?.superadmin === true ||
        token?.superAdmin === true);
}
function requireAdminAccess(request) {
    if (!hasAdminAccessFromRequest(request)) {
        throw new https_1.HttpsError("permission-denied", "admin access required");
    }
}
function sanitizeConversationPart(value) {
    return value.replaceAll("/", "_").trim();
}
function assertConversationParticipantAccess(participants, currentUserId) {
    if (!participants.includes(currentUserId)) {
        throw new https_1.HttpsError("permission-denied", "not allowed to access this conversation");
    }
}
async function deleteNotificationsForConversation(conversationId, userId) {
    const routeName = `/messages/${encodeURIComponent(conversationId)}`;
    const [conversationIdSnap, routeNameSnap] = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.notifications).where("conversationId", "==", conversationId).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.notifications).where("routeName", "==", routeName).get(),
    ]);
    const notificationDocs = new Map();
    for (const snapshot of [conversationIdSnap, routeNameSnap]) {
        for (const doc of snapshot.docs) {
            if (userId) {
                const docUserId = String(doc.data().userId || "").trim();
                if (docUserId != userId) {
                    continue;
                }
            }
            notificationDocs.set(doc.id, doc);
        }
    }
    if (notificationDocs.size == 0) {
        return new Set();
    }
    let batch = firestore_1.db.batch();
    let batchCount = 0;
    const affectedUserIds = new Set();
    for (const doc of notificationDocs.values()) {
        batch.delete(doc.ref);
        batchCount += 1;
        const userId = String(doc.data().userId || "").trim();
        if (userId) {
            affectedUserIds.add(userId);
        }
        if (batchCount >= 400) {
            await batch.commit();
            batch = firestore_1.db.batch();
            batchCount = 0;
        }
    }
    if (batchCount > 0) {
        await batch.commit();
    }
    return affectedUserIds;
}
function canonicalConversationId({ listingId, currentUserId, otherUserId, }) {
    const participants = [sanitizeConversationPart(currentUserId), sanitizeConversationPart(otherUserId)].sort();
    return `conv_${(0, hash_1.sha256)(`${sanitizeConversationPart(listingId)}::${participants.join("::")}`).slice(0, 32)}`;
}
function baseConversationThreadId(conversationId) {
    const normalizedConversationId = String(conversationId || "").trim();
    const markerIndex = normalizedConversationId.indexOf("__");
    if (markerIndex <= 0) {
        return normalizedConversationId;
    }
    return normalizedConversationId.slice(0, markerIndex);
}
function buildForkedConversationThreadId(conversationId) {
    const baseId = baseConversationThreadId(conversationId);
    const suffix = (0, node_crypto_1.randomUUID)().replaceAll("-", "").slice(0, 12);
    return `${baseId}__${suffix}`;
}
function shouldForkConversationThread(participants, deletedBy) {
    return participants.some((participantId) => deletedBy[participantId] === true);
}
function normalizeParticipantName(...values) {
    for (const value of values) {
        const normalized = String(value || "").trim();
        if (normalized)
            return normalized;
    }
    return "Utilisateur";
}
function readOfferOwnerId(data) {
    for (const field of ["ownerId", "userId", "uid"]) {
        const value = String(data[field] || "").trim();
        if (value)
            return value;
    }
    return "";
}
function resolveOfferLikeData({ offerData, listingData, }) {
    if (listingData != null) {
        return { data: listingData, source: "listings" };
    }
    if (offerData != null) {
        return { data: offerData, source: "offers" };
    }
    throw new https_1.HttpsError("not-found", "offer not found");
}
async function loadOfferLikeSnapshot(listingId) {
    const listingSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.listings).doc(listingId).get();
    if (listingSnap.exists) {
        return {
            data: (listingSnap.data() ?? {}),
            source: "listings",
        };
    }
    const offerSnap = await firestore_1.db.collection(constants_1.LEGACY_COLLECTIONS.offers).doc(listingId).get();
    return resolveOfferLikeData({
        offerData: offerSnap.exists
            ? (offerSnap.data() ?? {})
            : null,
        listingData: listingSnap.exists
            ? (listingSnap.data() ?? {})
            : null,
    });
}
function readUserDisplayName(data, ...fallbacks) {
    return normalizeParticipantName(data?.displayName, data?.display_name, data?.name, ...fallbacks);
}
function sanitizeMessageText(value) {
    return String(value ?? "")
        .split("\n")
        .map((line) => line.replace(/\s+$/g, ""))
        .join("\n")
        .trim();
}
const ALLOWED_AUDIO_ATTACHMENT_MIME_TYPES = new Set([
    "audio/mp4",
    "audio/m4a",
    "audio/aac",
    "audio/x-m4a",
    "audio/webm",
    "audio/mpeg",
    "audio/mp3",
    "audio/wav",
    "audio/x-wav",
    "audio/wave",
    "audio/ogg",
]);
function buildMessagingEntitlementError(reason) {
    switch (reason) {
        case "subscription_document_required":
            return new https_1.HttpsError("failed-precondition", "documents require ilipresto_plus when free access mode is disabled", { reason });
        case "free_plan_photo_limit_reached":
            return new https_1.HttpsError("failed-precondition", "free plan is limited to one photo per conversation", { reason });
        case "free_plan_audio_limit_reached":
            return new https_1.HttpsError("failed-precondition", "free plan is limited to one audio attachment per conversation", { reason });
    }
}
function buildMessagingModerationError(details) {
    let reason = "messaging_content_review_required";
    if (details.autoFlags.includes("banned_term")) {
        reason = "messaging_text_blocked";
    }
    else if (details.autoFlags.includes("adult_content") ||
        details.autoFlags.includes("violent_content")) {
        reason = "messaging_image_blocked";
    }
    return new https_1.HttpsError("failed-precondition", details.userMessage || "message requires moderation before send", {
        reason,
        moderationReason: details.moderationReason,
    });
}
function normalizeSubscriptionPlan(value) {
    const normalized = String(value ?? "").trim().toLowerCase();
    if (normalized === "ilipresto_plus" || normalized === "iliprestoplus" || normalized === "ilipresto+") {
        return "ilipresto_plus";
    }
    if (normalized === "ilipro") {
        return "ilipro";
    }
    return "free";
}
function getMessagingAttachmentEntitlements(plan, freeAccessMode = true) {
    if (freeAccessMode) {
        return {
            canSendDocuments: true,
            maxPhotosPerConversation: 999,
            maxAudioPerConversation: 999,
        };
    }
    switch (normalizeSubscriptionPlan(plan)) {
        case "ilipresto_plus":
        case "ilipro":
            return {
                canSendDocuments: true,
                maxPhotosPerConversation: 999,
                maxAudioPerConversation: 999,
            };
        default:
            return {
                canSendDocuments: false,
                maxPhotosPerConversation: 1,
                maxAudioPerConversation: 1,
            };
    }
}
async function readSubscriptionConfigFreeAccessMode() {
    const [snakeCaseSnap, camelCaseSnap] = await Promise.all([
        firestore_1.db.collection("app_config").doc("subscriptions").get().catch(() => null),
        firestore_1.db.collection(constants_1.COLLECTIONS.appConfig).doc("subscriptions").get().catch(() => null),
    ]);
    const data = snakeCaseSnap?.data() ?? camelCaseSnap?.data() ?? {};
    return data.freeAccessMode !== false;
}
async function enforceMessagingAttachmentEntitlements({ convRef, currentUserId, attachments, }) {
    if (attachments.length === 0) {
        return;
    }
    const freeAccessMode = await readSubscriptionConfigFreeAccessMode();
    if (freeAccessMode) {
        return;
    }
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(currentUserId).get();
    const entitlements = getMessagingAttachmentEntitlements(userSnap.data()?.subscriptionPlan, freeAccessMode);
    const requestedDocuments = attachments.filter((attachment) => attachment.type === "document").length;
    const requestedPhotos = attachments.filter((attachment) => attachment.type === "image").length;
    const requestedAudios = attachments.filter((attachment) => attachment.type === "audio").length;
    if (requestedDocuments > 0 && !entitlements.canSendDocuments) {
        throw buildMessagingEntitlementError("subscription_document_required");
    }
    if (requestedPhotos === 0 && requestedAudios === 0) {
        return;
    }
    const sentMessagesSnap = await convRef.collection("messages")
        .where("senderId", "==", currentUserId)
        .get();
    let existingPhotos = 0;
    let existingAudios = 0;
    for (const doc of sentMessagesSnap.docs) {
        const data = doc.data();
        if (data.deletedAt || data.isDeleted === true) {
            continue;
        }
        const rawAttachments = Array.isArray(data.attachments) ? data.attachments : [];
        for (const rawAttachment of rawAttachments) {
            const attachmentType = String(rawAttachment?.type || "").trim();
            if (attachmentType === "image") {
                existingPhotos++;
            }
            else if (attachmentType === "audio") {
                existingAudios++;
            }
        }
    }
    if (existingPhotos + requestedPhotos > entitlements.maxPhotosPerConversation) {
        throw buildMessagingEntitlementError("free_plan_photo_limit_reached");
    }
    if (existingAudios + requestedAudios > entitlements.maxAudioPerConversation) {
        throw buildMessagingEntitlementError("free_plan_audio_limit_reached");
    }
}
function buildAttachmentMessageFallbackText(attachment) {
    if (attachment.type === "image") {
        return `Photo : ${attachment.name}`;
    }
    if (attachment.type === "audio") {
        return "Note vocale";
    }
    return `Document : ${attachment.name}`;
}
const ADMIN_MESSAGING_CALLABLE_OPTIONS = {
    ...MESSAGING_CALLABLE_OPTIONS,
    enforceAppCheck: false,
};
function sanitizeAttachmentText(value, maxLength) {
    return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}
function isAllowedDocumentAttachmentMimeType(mimeType) {
    return mimeType.startsWith("text/") || [
        "application/pdf",
        "application/rtf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.oasis.opendocument.text",
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ].includes(mimeType);
}
function buildProcessedConversationAttachmentPath({ uid, conversationId, storagePath, }) {
    const expectedPrefix = `messageAttachments/${uid}/${conversationId}/`;
    if (!storagePath.startsWith(expectedPrefix)) {
        throw new https_1.HttpsError("permission-denied", "Unauthorized storage path");
    }
    if (storagePath.includes("..") || storagePath.includes("\\") || storagePath.startsWith("/")) {
        throw new https_1.HttpsError("invalid-argument", "Invalid storage path");
    }
    const baseName = node_path_1.posix.basename(storagePath).replace(/\.[^/.]+$/, "");
    return `${expectedPrefix}processed_${baseName}.webp`;
}
exports.processConversationAttachmentPhoto = (0, https_1.onCall)({
    ...MESSAGING_CALLABLE_OPTIONS,
    timeoutSeconds: 60,
    memory: "512MiB",
    cpu: 1,
    concurrency: 4,
    maxInstances: 20,
}, async (request) => {
    const uid = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    const storagePath = String(request.data?.storagePath || "").trim();
    if (!conversationId || !storagePath) {
        throw new https_1.HttpsError("invalid-argument", "conversationId and storagePath are required");
    }
    await loadConversationForParticipant(conversationId, uid);
    const destinationPath = buildProcessedConversationAttachmentPath({
        uid,
        conversationId,
        storagePath,
    });
    const bucket = firebase_admin_1.default.storage().bucket();
    const sourceFile = bucket.file(storagePath);
    let sourceBuffer;
    try {
        const [buffer] = await sourceFile.download();
        sourceBuffer = buffer;
    }
    catch {
        throw new https_1.HttpsError("not-found", "Source photo not found");
    }
    let outputBuffer;
    let width = 0;
    let height = 0;
    try {
        const processed = await (0, sharp_1.default)(sourceBuffer)
            .rotate()
            .resize({
            width: CONVERSATION_IMAGE_MAX_EDGE,
            height: CONVERSATION_IMAGE_MAX_EDGE,
            fit: "inside",
            withoutEnlargement: true,
        })
            .webp({ quality: 82, effort: 5 })
            .toBuffer({ resolveWithObject: true });
        outputBuffer = processed.data;
        width = processed.info.width ?? 0;
        height = processed.info.height ?? 0;
    }
    catch {
        throw new https_1.HttpsError("internal", "Image processing failed");
    }
    const token = (0, node_crypto_1.randomUUID)();
    try {
        await bucket.file(destinationPath).save(outputBuffer, {
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
        await sourceFile.delete();
    }
    catch {
        // best effort
    }
    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destinationPath)}?alt=media&token=${token}`;
    return {
        ok: true,
        storagePath: destinationPath,
        downloadUrl,
        thumbnailUrl: downloadUrl,
        mimeType: "image/webp",
        width,
        height,
        sizeBytes: outputBuffer.length,
    };
});
function sanitizeConversationAttachments(value, currentUserId, conversationId) {
    if (value == null)
        return [];
    if (!Array.isArray(value)) {
        throw new https_1.HttpsError("invalid-argument", "attachments must be an array");
    }
    if (value.length > 4) {
        throw new https_1.HttpsError("invalid-argument", "too many attachments");
    }
    return value.map((entry, index) => {
        if (!entry || typeof entry !== "object") {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} is invalid`);
        }
        const raw = entry;
        const type = sanitizeAttachmentText(raw.type, 24);
        if (type !== "image" && type !== "document" && type !== "audio") {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} type is invalid`);
        }
        const name = sanitizeAttachmentText(raw.name, 140) ||
            (type === "image" ? "Photo" : type === "audio" ? "Note vocale" : "Document");
        const url = String(raw.url ?? "").trim();
        const storagePath = String(raw.storagePath ?? "").trim();
        const mimeType = sanitizeAttachmentText(raw.mimeType, 120);
        const sizeBytes = Number(raw.sizeBytes || 0);
        let parsedUrl;
        try {
            parsedUrl = new URL(url);
        }
        catch (_) {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} url is invalid`);
        }
        if (parsedUrl.protocol !== "https:" ||
            !["firebasestorage.googleapis.com", "storage.googleapis.com"].includes(parsedUrl.hostname) ||
            !storagePath.startsWith(`messageAttachments/${currentUserId}/${conversationId}/`)) {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} storage is invalid`);
        }
        if (storagePath.includes("..") || storagePath.includes("\\") || storagePath.startsWith("/")) {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} storage path is invalid`);
        }
        if (!mimeType || !Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > 20 * 1024 * 1024) {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} metadata is invalid`);
        }
        if (type === "image" && !mimeType.startsWith("image/")) {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} must be an image`);
        }
        if (type === "image" &&
            (mimeType !== "image/webp" ||
                !storagePath.toLowerCase().endsWith(".webp") ||
                !name.toLowerCase().endsWith(".webp"))) {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} image must be processed as WebP before sending`);
        }
        if (type === "document" && !isAllowedDocumentAttachmentMimeType(mimeType)) {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} document type is invalid`);
        }
        if (type === "audio" && !ALLOWED_AUDIO_ATTACHMENT_MIME_TYPES.has(mimeType)) {
            throw new https_1.HttpsError("invalid-argument", `attachment #${index + 1} audio type is invalid`);
        }
        return {
            type,
            name,
            url,
            storagePath,
            mimeType,
            sizeBytes: Math.round(sizeBytes),
        };
    });
}
function mergeConversationParticipants(existingParticipants, requiredParticipants) {
    return [...existingParticipants, ...requiredParticipants]
        .map((value) => String(value || "").trim())
        .filter(Boolean)
        .filter((value, index, all) => all.indexOf(value) === index)
        .sort();
}
function toDateOrNull(value) {
    if (value instanceof firebase_admin_1.default.firestore.Timestamp)
        return value.toDate();
    if (value instanceof Date)
        return value;
    if (typeof value === "number" && Number.isFinite(value))
        return new Date(value);
    return null;
}
function computeUnreadCountAfterMessageDeletion({ participants, unreadCount, lastReadAt, deletedSenderId, deletedCreatedAt, }) {
    const result = {};
    for (const participantId of participants) {
        const currentUnread = Number(unreadCount[participantId] || 0);
        if (participantId === deletedSenderId || deletedCreatedAt == null) {
            result[participantId] = Math.max(0, currentUnread);
            continue;
        }
        const lastReadAtForParticipant = toDateOrNull(lastReadAt[participantId]);
        const shouldDecrement = !lastReadAtForParticipant || deletedCreatedAt > lastReadAtForParticipant;
        result[participantId] = Math.max(0, currentUnread - (shouldDecrement ? 1 : 0));
    }
    return result;
}
function canAccessConversation(data, uid, participants, options = {}) {
    const detectedFields = [];
    // (a) uid présent dans les participants canoniques (couvre participants, participantIds,
    //     participant_ids, userIds, memberIds, et les clés des maps participantNames, unreadCount, etc.)
    if (participants.includes(uid)) {
        detectedFields.push("participants");
        return { allowed: true, reason: "participants", detectedFields };
    }
    // Champs tableau supplémentaires non couverts par readConversationParticipants
    for (const field of ["users"]) {
        const raw = data[field];
        if (Array.isArray(raw)) {
            detectedFields.push(field);
            if (raw.some((v) => String(v || "").trim() === uid)) {
                return { allowed: true, reason: field, detectedFields };
            }
        }
    }
    // Map participantsMap: { [uid]: true }
    const participantsMap = data["participantsMap"];
    if (participantsMap && typeof participantsMap === "object") {
        detectedFields.push("participantsMap");
        if (participantsMap[uid] === true) {
            return { allowed: true, reason: "participantsMap", detectedFields };
        }
    }
    // (b) Champs scalaires owner / assignee
    for (const field of ["createdBy", "ownerId", "requesterId", "userId", "adminId", "assigneeId"]) {
        const value = String(data[field] || "").trim();
        if (value) {
            detectedFields.push(field);
            if (value === uid) {
                return { allowed: true, reason: field, detectedFields };
            }
        }
    }
    // (c) Accès admin global (support / modération)
    if (options.isAdmin === true) {
        return { allowed: true, reason: "admin", detectedFields };
    }
    return { allowed: false, reason: "none", detectedFields };
}
async function loadConversationForParticipant(conversationId, currentUserId, options = {}) {
    const convRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
        throw new https_1.HttpsError("not-found", "conversation not found");
    }
    const data = (convSnap.data() ?? {});
    const conversation = (0, mirror_1.readConversationMirrorData)(data, { conversationId });
    const participants = conversation.participants;
    const access = canAccessConversation(data, currentUserId, participants, { isAdmin: options.isAdmin });
    logger_1.logger.info("conversation_access_check", {
        conversationId_len: conversationId.length,
        uid_len: currentUserId.length,
        isAdmin: options.isAdmin ?? false,
        detectedFields: access.detectedFields,
        allowedReason: access.reason,
    });
    if (!access.allowed) {
        throw new https_1.HttpsError("permission-denied", "not allowed to access this conversation");
    }
    return { convRef, data, participants, conversation };
}
exports.ensureOfferConversation = (0, https_1.onCall)(MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const listingId = String(request.data?.listingId || request.data?.offerId || "").trim();
    const otherUserId = String(request.data?.otherUserId || "").trim();
    if (!listingId || !otherUserId) {
        throw new https_1.HttpsError("invalid-argument", "listingId and otherUserId are required");
    }
    if (currentUserId == otherUserId) {
        throw new https_1.HttpsError("failed-precondition", "cannot create a conversation with yourself");
    }
    const { data: offerData, source: offerSource } = await loadOfferLikeSnapshot(listingId);
    const offerOwnerId = readOfferOwnerId(offerData);
    if (!offerOwnerId) {
        throw new https_1.HttpsError("failed-precondition", `${offerSource} owner is missing`);
    }
    if (offerOwnerId != otherUserId) {
        throw new https_1.HttpsError("permission-denied", `conversation target does not match ${offerSource} owner`);
    }
    const offerTitle = String(offerData.listingTitle ||
        offerData.offerTitle ||
        offerData.title ||
        request.data?.listingTitle ||
        request.data?.offerTitle ||
        "").trim();
    if (!offerTitle) {
        throw new https_1.HttpsError("failed-precondition", "offer title is missing");
    }
    const [currentUserSnap, otherUserSnap] = await Promise.all([
        firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(currentUserId).get(),
        firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(otherUserId).get(),
    ]);
    const currentUserName = readUserDisplayName(currentUserSnap.data(), request.auth?.token?.name, request.auth?.token?.email, currentUserId);
    const otherUserName = readUserDisplayName(otherUserSnap.data(), offerData.advertiserName, otherUserId);
    const participantNames = {
        [currentUserId]: currentUserName,
        [otherUserId]: otherUserName,
    };
    const convCol = firestore_1.db.collection(constants_1.COLLECTIONS.conversations);
    const existingDocs = await findConversationSnapshotsForParticipant(currentUserId, listingId);
    for (const doc of existingDocs) {
        const docData = doc.data();
        const conversation = (0, mirror_1.readConversationMirrorData)(docData, { conversationId: doc.id });
        if (!conversation.participants.includes(otherUserId))
            continue;
        const normalizedParticipants = mergeConversationParticipants(conversation.participants, [currentUserId, otherUserId]);
        if ((0, state_1.isConversationBlocked)(docData)) {
            throw new https_1.HttpsError("failed-precondition", "conversation is blocked");
        }
        if (shouldForkConversationThread(normalizedParticipants, conversation.deletedBy)) {
            continue;
        }
        const archivedBy = {
            ...conversation.archivedBy,
            [currentUserId]: false,
        };
        const blockedBy = conversation.blockedBy;
        await doc.ref.set((0, mirror_1.buildConversationMirrorFields)({
            ...conversation,
            participants: normalizedParticipants,
            participantNames: {
                ...conversation.participantNames,
                ...participantNames,
            },
            otherUserName,
            listingId,
            listingTitle: offerTitle,
            offerId: listingId,
            offerTitle,
            archivedBy,
            blockedBy,
            status: (0, state_1.computeConversationStatus)(normalizedParticipants, archivedBy, blockedBy),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }), { merge: true });
        return {
            ok: true,
            conversationId: doc.id,
            offerTitle,
        };
    }
    const conversationId = canonicalConversationId({ listingId, currentUserId, otherUserId });
    const participants = [currentUserId, otherUserId].sort();
    const matchingConversationExists = existingDocs.some((doc) => {
        const docData = doc.data();
        const conversation = (0, mirror_1.readConversationMirrorData)(docData, { conversationId: doc.id });
        return conversation.participants.includes(otherUserId);
    });
    const targetConversationId = matchingConversationExists
        ? buildForkedConversationThreadId(conversationId)
        : conversationId;
    const convRef = convCol.doc(targetConversationId);
    if (targetConversationId != conversationId) {
        await convRef.set((0, mirror_1.buildConversationMirrorFields)({
            participants,
            participantNames,
            otherUserName,
            listingId,
            listingTitle: offerTitle,
            offerId: listingId,
            offerTitle,
            status: "open",
            archivedBy: {},
            deletedBy: {},
            blockedBy: {},
            lastReadAt: {},
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessage: "",
            lastSenderId: "",
            lastSenderName: "",
            messageCount: 0,
            unreadCount: {
                [currentUserId]: 0,
                [otherUserId]: 0,
            },
        }), { merge: false });
        return {
            ok: true,
            conversationId: convRef.id,
            offerTitle,
        };
    }
    await firestore_1.db.runTransaction(async (transaction) => {
        const snap = await transaction.get(convRef);
        if (snap.exists) {
            const data = (snap.data() ?? {});
            const conversation = (0, mirror_1.readConversationMirrorData)(data, { conversationId: convRef.id });
            const normalizedParticipants = mergeConversationParticipants(conversation.participants, participants);
            const archivedBy = {
                ...conversation.archivedBy,
                [currentUserId]: false,
            };
            const blockedBy = conversation.blockedBy;
            transaction.set(convRef, (0, mirror_1.buildConversationMirrorFields)({
                ...conversation,
                participants: normalizedParticipants,
                participantNames: {
                    ...conversation.participantNames,
                    ...participantNames,
                },
                otherUserName,
                listingId,
                listingTitle: offerTitle,
                offerId: listingId,
                offerTitle,
                archivedBy,
                blockedBy,
                status: (0, state_1.computeConversationStatus)(normalizedParticipants, archivedBy, blockedBy),
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }), { merge: true });
            return;
        }
        transaction.set(convRef, (0, mirror_1.buildConversationMirrorFields)({
            participants,
            participantNames,
            otherUserName,
            listingId,
            listingTitle: offerTitle,
            offerId: listingId,
            offerTitle,
            status: "open",
            archivedBy: {},
            blockedBy: {},
            lastReadAt: {},
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            lastMessage: "",
            lastSenderId: "",
            lastSenderName: "",
            messageCount: 0,
            unreadCount: {
                [currentUserId]: 0,
                [otherUserId]: 0,
            },
        }));
    });
    return {
        ok: true,
        conversationId,
        listingId,
        offerTitle,
    };
});
exports.sendConversationMessage = (0, https_1.onCall)(HOT_MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    const text = sanitizeMessageText(request.data?.text);
    const attachments = sanitizeConversationAttachments(request.data?.attachments, currentUserId, conversationId);
    const firstAttachment = attachments[0];
    const messageText = text || (firstAttachment
        ? buildAttachmentMessageFallbackText(firstAttachment)
        : "");
    if (!conversationId || !messageText) {
        throw new https_1.HttpsError("invalid-argument", "conversationId and text or attachment are required");
    }
    if (messageText.length > 4000) {
        throw new https_1.HttpsError("invalid-argument", "message is too long");
    }
    const canSend = await (0, rate_limit_1.canProceedRateLimited)("msg_send", `${currentUserId}:${conversationId}`, MESSAGE_SEND_LIMIT, MESSAGE_SEND_WINDOW_MS);
    if (!canSend) {
        throw new https_1.HttpsError("resource-exhausted", "too many messages sent too quickly");
    }
    const { convRef } = await loadConversationForParticipant(conversationId, currentUserId);
    await enforceMessagingAttachmentEntitlements({
        convRef,
        currentUserId,
        attachments,
    });
    const moderationMode = await (0, moderation_1.loadMessagingModerationMode)();
    let messageModeration = (0, moderation_1.shouldModerateSynchronouslyBeforeSend)(moderationMode)
        ? await (0, moderation_1.evaluateMessagingModeration)({
            mode: moderationMode,
            text: messageText,
            attachments,
        })
        : (0, moderation_1.buildPendingMessagingModeration)(moderationMode);
    if ((0, moderation_1.shouldModerateSynchronouslyBeforeSend)(moderationMode) && messageModeration.status !== "approved") {
        throw buildMessagingModerationError({
            moderationReason: messageModeration.moderationReason,
            autoFlags: messageModeration.autoFlags,
            userMessage: messageModeration.userMessage,
        });
    }
    const latestMessageSnap = await convRef
        .collection("messages")
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();
    const latestMessageDoc = latestMessageSnap.docs[0];
    if (latestMessageDoc) {
        const latestData = latestMessageDoc.data();
        const latestSenderId = String(latestData.senderId || "").trim();
        const latestText = sanitizeMessageText(latestData.text);
        const latestCreatedAt = toDateOrNull(latestData.createdAt);
        if (attachments.length === 0 &&
            latestSenderId === currentUserId &&
            latestText === messageText &&
            latestCreatedAt != null &&
            Date.now() - latestCreatedAt.getTime() <= DUPLICATE_MESSAGE_WINDOW_MS) {
            return {
                ok: true,
                deduplicated: true,
                messageId: latestMessageDoc.id,
            };
        }
    }
    const senderUserSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(currentUserId).get();
    const senderName = readUserDisplayName(senderUserSnap.data(), request.auth?.token?.name, request.auth?.token?.email, currentUserId);
    const messageRef = convRef.collection("messages").doc();
    let participantsToRefresh = [];
    let effectiveConversationId = conversationId;
    let effectiveMessageId = messageRef.id;
    await firestore_1.db.runTransaction(async (transaction) => {
        const convSnap = await transaction.get(convRef);
        if (!convSnap.exists) {
            throw new https_1.HttpsError("not-found", "conversation not found");
        }
        const data = (convSnap.data() ?? {});
        const conversation = (0, mirror_1.readConversationMirrorData)(data, { conversationId });
        const participants = conversation.participants;
        assertConversationParticipantAccess(participants, currentUserId);
        if ((0, state_1.isConversationBlocked)(data)) {
            throw new https_1.HttpsError("failed-precondition", "conversation is blocked");
        }
        const isFirstMessage = (0, mirror_1.readConversationMessageCount)(data) === 0;
        transaction.set(messageRef, {
            text: messageText,
            body: messageText,
            attachments,
            moderation: {
                mode: messageModeration.mode,
                status: messageModeration.status,
                visibility: messageModeration.visibility,
                reason: messageModeration.moderationReason,
                userMessage: messageModeration.userMessage,
                autoFlags: messageModeration.autoFlags,
                riskScore: messageModeration.riskScore,
                textScanStatus: messageModeration.textScanStatus,
                imageScanStatus: messageModeration.imageScanStatus,
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            },
            senderId: currentUserId,
            sender_id: currentUserId,
            senderName,
            sender_name: senderName,
            isFirstMessage,
            createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            created_at: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        const archivedBy = {
            ...conversation.archivedBy,
        };
        const deletedBy = {
            ...conversation.deletedBy,
        };
        const unreadCount = {
            ...conversation.unreadCount,
        };
        if (shouldForkConversationThread(participants, deletedBy)) {
            const forkedConversationId = buildForkedConversationThreadId(conversationId);
            const forkedConvRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(forkedConversationId);
            const forkedMessageRef = forkedConvRef.collection("messages").doc();
            const retiredArchivedBy = {
                ...archivedBy,
                [currentUserId]: true,
            };
            const retiredDeletedBy = {
                ...deletedBy,
                [currentUserId]: true,
            };
            const freshArchivedBy = Object.fromEntries(participants.map((participantId) => [participantId, false]));
            const freshDeletedBy = Object.fromEntries(participants.map((participantId) => [participantId, false]));
            const freshBlockedBy = Object.fromEntries(participants.map((participantId) => [participantId, false]));
            const freshUnreadCount = Object.fromEntries(participants.map((participantId) => [
                participantId,
                participantId == currentUserId ? 0 : firebase_admin_1.default.firestore.FieldValue.increment(1),
            ]));
            transaction.set(forkedMessageRef, {
                text: messageText,
                body: messageText,
                attachments,
                moderation: {
                    mode: messageModeration.mode,
                    status: messageModeration.status,
                    visibility: messageModeration.visibility,
                    reason: messageModeration.moderationReason,
                    userMessage: messageModeration.userMessage,
                    autoFlags: messageModeration.autoFlags,
                    riskScore: messageModeration.riskScore,
                    textScanStatus: messageModeration.textScanStatus,
                    imageScanStatus: messageModeration.imageScanStatus,
                    updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                },
                senderId: currentUserId,
                sender_id: currentUserId,
                senderName,
                sender_name: senderName,
                isFirstMessage: true,
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                created_at: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            transaction.set(forkedConvRef, (0, mirror_1.buildConversationMirrorFields)({
                ...conversation,
                participants,
                participantNames: {
                    ...conversation.participantNames,
                    [currentUserId]: senderName,
                },
                archivedBy: freshArchivedBy,
                deletedBy: freshDeletedBy,
                blockedBy: freshBlockedBy,
                unreadCount: freshUnreadCount,
                status: "open",
                lastReadAt: {},
                createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                lastMessage: messageText,
                lastSenderId: currentUserId,
                lastSenderName: senderName,
                lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
                messageCount: 1,
            }), { merge: false });
            transaction.update(convRef, (0, mirror_1.buildConversationMirrorFields)({
                ...conversation,
                participants,
                archivedBy: retiredArchivedBy,
                deletedBy: retiredDeletedBy,
                blockedBy: conversation.blockedBy,
                unreadCount: {
                    ...conversation.unreadCount,
                    [currentUserId]: 0,
                },
                status: (0, state_1.computeConversationStatus)(participants, retiredArchivedBy, conversation.blockedBy),
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }));
            participantsToRefresh = participants;
            effectiveConversationId = forkedConversationId;
            effectiveMessageId = forkedMessageRef.id;
            return;
        }
        for (const participantId of participants) {
            archivedBy[participantId] = false;
            deletedBy[participantId] = false;
            unreadCount[participantId] = participantId == currentUserId
                ? 0
                : firebase_admin_1.default.firestore.FieldValue.increment(1);
        }
        transaction.update(convRef, (0, mirror_1.buildConversationMirrorFields)({
            ...conversation,
            participants,
            participantNames: {
                ...conversation.participantNames,
                [currentUserId]: senderName,
            },
            archivedBy,
            deletedBy,
            unreadCount,
            lastMessage: messageText,
            lastSenderId: currentUserId,
            lastSenderName: senderName,
            status: "open",
            lastMessageAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            messageCount: firebase_admin_1.default.firestore.FieldValue.increment(1),
        }));
        participantsToRefresh = participants;
    });
    await Promise.all(participantsToRefresh.map((participantId) => (0, counters_1.refreshUnreadMessageCount)(participantId)));
    return {
        ok: true,
        messageId: effectiveMessageId,
        conversationId: effectiveConversationId,
    };
});
exports.markConversationRead = (0, https_1.onCall)(HOT_MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const roles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    const isAdmin = roles.includes("admin") || roles.includes("superadmin");
    const { convRef, conversation } = await loadConversationForParticipant(conversationId, currentUserId, { isAdmin });
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        unreadCount: {
            ...conversation.unreadCount,
            [currentUserId]: 0,
        },
        lastReadAt: {
            ...conversation.lastReadAt,
            [currentUserId]: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    await (0, counters_1.refreshUnreadMessageCount)(currentUserId);
    return { ok: true };
});
exports.archiveConversation = (0, https_1.onCall)(MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = {
        ...conversation.archivedBy,
        [currentUserId]: true,
    };
    const blockedBy = conversation.blockedBy;
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    return { ok: true };
});
exports.unarchiveConversation = (0, https_1.onCall)(MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = {
        ...conversation.archivedBy,
        [currentUserId]: false,
    };
    const deletedBy = {
        ...conversation.deletedBy,
        [currentUserId]: false,
    };
    const blockedBy = conversation.blockedBy;
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        deletedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    return { ok: true };
});
exports.blockConversation = (0, https_1.onCall)(MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    const archivedBy = conversation.archivedBy;
    const blockedBy = {
        ...conversation.blockedBy,
        [currentUserId]: true,
    };
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    return { ok: true };
});
exports.unblockConversation = (0, https_1.onCall)(MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, data, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    if (!(0, state_1.isConversationFlagEnabledForUser)(data, "blockedBy", currentUserId)) {
        return { ok: true };
    }
    const archivedBy = (0, state_1.readConversationFlagMap)(data, "archivedBy");
    const blockedBy = {
        ...conversation.blockedBy,
        [currentUserId]: false,
    };
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    return { ok: true };
});
exports.adminUnblockConversation = (0, https_1.onCall)(ADMIN_MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    requireAdminAccess(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    const { convRef, data, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId, { isAdmin: true });
    const archivedBy = (0, state_1.readConversationFlagMap)(data, "archivedBy");
    const blockedBy = {};
    for (const participantId of participants) {
        blockedBy[participantId] = false;
    }
    await convRef.update((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        archivedBy,
        blockedBy,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }));
    logger_1.logger.info("admin_unblocked_conversation", {
        conversationId_len: conversationId.length,
        adminUid_len: currentUserId.length,
        participantCount: participants.length,
    });
    // Le déblocage force l'état d'une conversation privée : il doit rester
    // attribuable à un administrateur nommé.
    await (0, admin_audit_1.writeAdminActionLog)({
        actorId: currentUserId,
        actorRole: (0, roles_1.extractRolesFromAuthToken)(request.auth?.token).includes("superadmin")
            ? "superadmin"
            : "admin",
        actionType: "admin_unblock_conversation",
        targetType: "conversation",
        targetId: conversationId,
        after: { participantCount: participants.length },
    });
    return { ok: true };
});
exports.deleteConversation = (0, https_1.onCall)(MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    if (!conversationId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId is required");
    }
    // --- Standard path: full access check + mirror update ---
    try {
        const { convRef, data, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
        const notificationUserIds = await deleteNotificationsForConversation(conversationId, currentUserId);
        const archivedBy = (0, state_1.readConversationFlagMap)(data, "archivedBy");
        const deletedBy = (0, state_1.readConversationFlagMap)(data, "deletedBy");
        const blockedBy = (0, state_1.readConversationFlagMap)(data, "blockedBy");
        const unreadCount = {
            ...conversation.unreadCount,
            [currentUserId]: 0,
        };
        archivedBy[currentUserId] = true;
        deletedBy[currentUserId] = true;
        await convRef.update((0, mirror_1.buildConversationMirrorFields)({
            ...conversation,
            participants,
            archivedBy,
            deletedBy,
            blockedBy,
            unreadCount,
            status: (0, state_1.computeConversationStatus)(participants, archivedBy, blockedBy),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }));
        await (0, counters_1.refreshUnreadMessageCount)(currentUserId);
        await Promise.all(Array.from(notificationUserIds, (userId) => (0, counters_1.refreshUnreadNotificationCount)(userId)));
        return { ok: true };
    }
    catch (err) {
        // --- Permissive fallback: conversation exists but participant data is missing ---
        // Applies to old-format conversations (test messages, deleted-account participants).
        // Safe because deleteConversation is a soft-delete that only marks visibility
        // for the requesting user without exposing or modifying data for others.
        const isPermissionDenied = err instanceof https_1.HttpsError && err.code === "permission-denied";
        if (!isPermissionDenied) {
            throw err;
        }
        const convRef = firestore_1.db.collection(constants_1.COLLECTIONS.conversations).doc(conversationId);
        const convSnap = await convRef.get();
        if (!convSnap.exists) {
            throw new https_1.HttpsError("not-found", "conversation not found");
        }
        logger_1.logger.info("deleteConversation_permissive_fallback", {
            conversationId_len: conversationId.length,
            uid_len: currentUserId.length,
        });
        await convRef.update({
            [`deletedBy.${currentUserId}`]: true,
            [`archivedBy.${currentUserId}`]: true,
            [`unreadCount.${currentUserId}`]: 0,
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        await (0, counters_1.refreshUnreadMessageCount)(currentUserId);
        return { ok: true, fallback: true };
    }
});
exports.deleteConversationMessage = (0, https_1.onCall)(MESSAGING_CALLABLE_OPTIONS, async (request) => {
    const currentUserId = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    const messageId = String(request.data?.messageId || "").trim();
    if (!conversationId || !messageId) {
        throw new https_1.HttpsError("invalid-argument", "conversationId and messageId are required");
    }
    const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
    const messageRef = convRef.collection("messages").doc(messageId);
    const messageSnap = await messageRef.get();
    if (!messageSnap.exists) {
        throw new https_1.HttpsError("not-found", "message not found");
    }
    const messageData = (messageSnap.data() ?? {});
    const senderId = String(messageData.senderId || messageData.sender_id || "").trim();
    const deletedCreatedAt = toDateOrNull(messageData.createdAt || messageData.created_at);
    if (senderId !== currentUserId) {
        throw new https_1.HttpsError("permission-denied", "you can only delete your own messages");
    }
    // Soft-delete: clear content and mark as deleted so a placeholder appears in the thread.
    await messageRef.update({
        text: "",
        body: "",
        attachments: [],
        deletedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        deletedBy: currentUserId,
    });
    // Delete Storage files that were attached (best-effort, errors are ignored).
    const rawAttachments = Array.isArray(messageData.attachments) ? messageData.attachments : [];
    const storagePaths = [];
    for (const att of rawAttachments) {
        const sp = String(att.storagePath || "").trim();
        if (sp)
            storagePaths.push(sp);
    }
    if (storagePaths.length > 0) {
        const bucket = firebase_admin_1.default.storage().bucket();
        await Promise.allSettled(storagePaths.map((sp) => bucket.file(sp).delete()));
    }
    const messagesRef = convRef.collection("messages");
    const [latestMessageSnap, messageCountSnap] = await Promise.all([
        messagesRef.orderBy("createdAt", "desc").limit(1).get(),
        messagesRef.count().get(),
    ]);
    const latestRaw = latestMessageSnap.docs[0]?.data();
    // Show a placeholder text in the conversation list if the latest message was deleted.
    const latestMessage = (latestRaw
        ? { ...latestRaw, text: latestRaw.deletedAt ? "Message supprimé" : (latestRaw.text ?? latestRaw.body) }
        : undefined);
    const remainingMessageCount = messageCountSnap.data().count;
    const unreadCount = computeUnreadCountAfterMessageDeletion({
        participants,
        unreadCount: conversation.unreadCount,
        lastReadAt: conversation.lastReadAt,
        deletedSenderId: senderId,
        deletedCreatedAt,
    });
    const archivedBy = {
        ...conversation.archivedBy,
    };
    for (const participantId of participants) {
        archivedBy[participantId] = false;
    }
    await convRef.set((0, mirror_1.buildConversationMirrorFields)({
        ...conversation,
        participants,
        unreadCount,
        archivedBy,
        lastMessage: latestMessage
            ? (latestRaw?.deletedAt
                ? "Message supprimé"
                : sanitizeMessageText(latestMessage.text ?? latestMessage.body))
            : "",
        lastSenderId: latestMessage
            ? String(latestMessage.senderId || latestMessage.sender_id || "").trim()
            : "",
        lastSenderName: latestMessage
            ? normalizeParticipantName(latestMessage.senderName, latestMessage.sender_name)
            : "",
        lastMessageAt: latestMessage?.createdAt ?? latestMessage?.created_at,
        messageCount: remainingMessageCount,
        status: (0, state_1.computeConversationStatus)(participants, archivedBy, conversation.blockedBy),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }), { merge: true });
    await Promise.all(participants.map((participantId) => (0, counters_1.refreshUnreadMessageCount)(participantId)));
    return { ok: true };
});
//# sourceMappingURL=callables.js.map