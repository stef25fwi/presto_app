import { randomUUID } from "node:crypto";
import { posix as pathPosix } from "node:path";

import admin from "../../core/firebase_admin_compat";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import sharp from "sharp";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { canProceedRateLimited } from "../../core/rate_limit";
import { COLLECTIONS, LEGACY_COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";
import { extractRolesFromAuthToken } from "../marketplace/services/roles";
import { refreshUnreadMessageCount, refreshUnreadNotificationCount } from "../notifications/counters";
import {
  buildPendingMessagingModeration,
  evaluateMessagingModeration,
  loadMessagingModerationMode,
  shouldModerateSynchronouslyBeforeSend,
} from "./moderation";
import {
  computeConversationStatus,
  isConversationBlocked,
  isConversationFlagEnabledForUser,
  readConversationFlagMap,
} from "./state";
import {
  CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES,
} from "./participants";
import {
  buildConversationMirrorFields,
  readConversationMessageCount,
  readConversationMirrorData,
} from "./mirror";

const MESSAGE_SEND_WINDOW_MS = 10 * 1000;
const MESSAGE_SEND_LIMIT = 6;
const DUPLICATE_MESSAGE_WINDOW_MS = 15 * 1000;
const CONVERSATION_IMAGE_MAX_EDGE = 960;

// Messaging is protected by Firebase Auth, participant checks, strict input
// validation and rate limits. Keeping App Check non-blocking here prevents a
// broken/rotating web reCAPTCHA domain from taking the whole inbox offline.
const MESSAGING_CALLABLE_OPTIONS = {
  region: PROJECT_REGION,
  enforceAppCheck: ENFORCE_APP_CHECK,
} as const;

// Chemin chaud de la messagerie : on garde 1 instance au chaud pour éliminer
// le cold start (sinon le 1er message après inactivité met ~2-5 s à partir).
// Appliqué uniquement aux callables critiques (envoi + marquage lu) pour
// limiter le coût (1 instance toujours active par fonction).
const HOT_MESSAGING_CALLABLE_OPTIONS = {
  ...MESSAGING_CALLABLE_OPTIONS,
  minInstances: 1,
} as const;

async function findConversationSnapshotsForParticipant(
  currentUserId: string,
  listingId?: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const conversationCollection = db.collection(COLLECTIONS.conversations);
  const listingFieldAliases = listingId ? ["listingId", "offerId", "offer_id"] as const : [null] as const;
  const snapshots = await Promise.all(
    CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.flatMap((participantField) =>
      listingFieldAliases.map((listingField) => {
        let query: FirebaseFirestore.Query = conversationCollection.where(
          participantField,
          "array-contains",
          currentUserId,
        );
        if (listingId && listingField) {
          query = query.where(listingField, "==", listingId);
        }
        return query.limit(20).get();
      }),
    ),
  );

  const deduped = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      deduped.set(doc.id, doc);
    }
  }
  return [...deduped.values()];
}

function requireAuthUid(request: { auth?: { uid?: string; token?: Record<string, unknown> } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "authentication required");
  }
  return uid;
}

function hasAdminAccessFromRequest(
  request: { auth?: { token?: Record<string, unknown> } },
): boolean {
  const token = request.auth?.token as Record<string, unknown> | undefined;
  const roles = extractRolesFromAuthToken(token);
  const primaryRole = String(
    token?.primaryRole || token?.role || token?.adminRole || "",
  )
    .trim()
    .toLowerCase();

  return (
    roles.includes("admin") ||
    roles.includes("superadmin") ||
    primaryRole === "admin" ||
    primaryRole === "superadmin" ||
    token?.admin === true ||
    token?.isAdmin === true ||
    token?.superadmin === true ||
    token?.superAdmin === true
  );
}

function requireAdminAccess(
  request: { auth?: { token?: Record<string, unknown> } },
): void {
  if (!hasAdminAccessFromRequest(request)) {
    throw new HttpsError("permission-denied", "admin access required");
  }
}

function sanitizeConversationPart(value: string): string {
  return value.replaceAll("/", "_").trim();
}

export function assertConversationParticipantAccess(
  participants: string[],
  currentUserId: string,
): void {
  if (!participants.includes(currentUserId)) {
    throw new HttpsError("permission-denied", "not allowed to access this conversation");
  }
}

async function deleteNotificationsForConversation(
  conversationId: string,
  userId?: string,
): Promise<Set<string>> {
  const routeName = `/messages/${encodeURIComponent(conversationId)}`;
  const [conversationIdSnap, routeNameSnap] = await Promise.all([
    db.collection(COLLECTIONS.notifications).where("conversationId", "==", conversationId).get(),
    db.collection(COLLECTIONS.notifications).where("routeName", "==", routeName).get(),
  ]);

  const notificationDocs = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
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
    return new Set<string>();
  }

  let batch = db.batch();
  let batchCount = 0;
  const affectedUserIds = new Set<string>();

  for (const doc of notificationDocs.values()) {
    batch.delete(doc.ref);
    batchCount += 1;

    const userId = String(doc.data().userId || "").trim();
    if (userId) {
      affectedUserIds.add(userId);
    }

    if (batchCount >= 400) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return affectedUserIds;
}

export function canonicalConversationId({
  listingId,
  currentUserId,
  otherUserId,
}: {
  listingId: string;
  currentUserId: string;
  otherUserId: string;
}): string {
  const participants = [sanitizeConversationPart(currentUserId), sanitizeConversationPart(otherUserId)].sort();
  return `conv_${sha256(`${sanitizeConversationPart(listingId)}::${participants.join("::")}`).slice(0, 32)}`;
}

function baseConversationThreadId(conversationId: string): string {
  const normalizedConversationId = String(conversationId || "").trim();
  const markerIndex = normalizedConversationId.indexOf("__");
  if (markerIndex <= 0) {
    return normalizedConversationId;
  }
  return normalizedConversationId.slice(0, markerIndex);
}

function buildForkedConversationThreadId(conversationId: string): string {
  const baseId = baseConversationThreadId(conversationId);
  const suffix = randomUUID().replaceAll("-", "").slice(0, 12);
  return `${baseId}__${suffix}`;
}

export function shouldForkConversationThread(
  participants: string[],
  deletedBy: Record<string, boolean>,
): boolean {
  return participants.some((participantId) => deletedBy[participantId] === true);
}

function normalizeParticipantName(...values: unknown[]): string {
  for (const value of values) {
    const normalized = String(value || "").trim();
    if (normalized) return normalized;
  }
  return "Utilisateur";
}

function readOfferOwnerId(data: Record<string, unknown>): string {
  for (const field of ["ownerId", "userId", "uid"]) {
    const value = String(data[field] || "").trim();
    if (value) return value;
  }
  return "";
}

export function resolveOfferLikeData({
  offerData,
  listingData,
}: {
  offerData?: Record<string, unknown> | null;
  listingData?: Record<string, unknown> | null;
}): {
  data: Record<string, unknown>;
  source: "offers" | "listings";
} {
  if (listingData != null) {
    return {data: listingData, source: "listings"};


  }

  if (offerData != null) {
    return {data: offerData, source: "offers"};
  }

  throw new HttpsError("not-found", "offer not found");
}

async function loadOfferLikeSnapshot(listingId: string): Promise<{
  data: Record<string, unknown>;
  source: "offers" | "listings";
}> {
  const listingSnap = await db.collection(COLLECTIONS.listings).doc(listingId).get();
  if (listingSnap.exists) {
    return {
      data: (listingSnap.data() ?? {}) as Record<string, unknown>,
      source: "listings",
    };
  }

  const offerSnap = await db.collection(LEGACY_COLLECTIONS.offers).doc(listingId).get();

  return resolveOfferLikeData({
    offerData: offerSnap.exists
      ? (offerSnap.data() ?? {}) as Record<string, unknown>
      : null,
    listingData: listingSnap.exists
      ? (listingSnap.data() ?? {}) as Record<string, unknown>
      : null,
  });
}

function readUserDisplayName(data: Record<string, unknown> | undefined, ...fallbacks: unknown[]): string {
  return normalizeParticipantName(
    data?.displayName,
    data?.display_name,
    data?.name,
    ...fallbacks,
  );
}

function sanitizeMessageText(value: unknown): string {
  return String(value ?? "")
    .split("\n")
    .map((line) => line.replace(/\s+$/g, ""))
    .join("\n")
    .trim();
}

type ConversationAttachment = {
  type: "image" | "document" | "audio";
  name: string;
  url: string;
  storagePath: string;
  mimeType: string;
  sizeBytes: number;
};

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

type MessagingAttachmentEntitlements = {
  canSendDocuments: boolean;
  maxPhotosPerConversation: number;
  maxAudioPerConversation: number;
};

type MessagingAttachmentEntitlementFailureReason =
  | "subscription_document_required"
  | "free_plan_photo_limit_reached"
  | "free_plan_audio_limit_reached";

function buildMessagingEntitlementError(
  reason: MessagingAttachmentEntitlementFailureReason,
): HttpsError {
  switch (reason) {
    case "subscription_document_required":
      return new HttpsError(
        "failed-precondition",
        "documents require ilipresto_plus when free access mode is disabled",
        { reason },
      );
    case "free_plan_photo_limit_reached":
      return new HttpsError(
        "failed-precondition",
        "free plan is limited to one photo per conversation",
        { reason },
      );
    case "free_plan_audio_limit_reached":
      return new HttpsError(
        "failed-precondition",
        "free plan is limited to one audio attachment per conversation",
        { reason },
      );
  }
}

function buildMessagingModerationError(details: {
  moderationReason: string;
  autoFlags: string[];
  userMessage: string;
}): HttpsError {
  let reason = "messaging_content_review_required";
  if (details.autoFlags.includes("banned_term")) {
    reason = "messaging_text_blocked";
  } else if (
    details.autoFlags.includes("adult_content") ||
    details.autoFlags.includes("violent_content")
  ) {
    reason = "messaging_image_blocked";
  }

  return new HttpsError(
    "failed-precondition",
    details.userMessage || "message requires moderation before send",
    {
      reason,
      moderationReason: details.moderationReason,
    },
  );
}

function normalizeSubscriptionPlan(value: unknown): "free" | "ilipresto_plus" | "ilipro" {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "ilipresto_plus" || normalized === "iliprestoplus" || normalized === "ilipresto+") {
    return "ilipresto_plus";
  }
  if (normalized === "ilipro") {
    return "ilipro";
  }
  return "free";
}

export function getMessagingAttachmentEntitlements(
  plan: unknown,
  freeAccessMode = true,
): MessagingAttachmentEntitlements {
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

async function readSubscriptionConfigFreeAccessMode(): Promise<boolean> {
  const [snakeCaseSnap, camelCaseSnap] = await Promise.all([
    db.collection("app_config").doc("subscriptions").get().catch(() => null),
    db.collection(COLLECTIONS.appConfig).doc("subscriptions").get().catch(() => null),
  ]);

  const data = snakeCaseSnap?.data() ?? camelCaseSnap?.data() ?? {};
  return data.freeAccessMode !== false;
}

async function enforceMessagingAttachmentEntitlements({
  convRef,
  currentUserId,
  attachments,
}: {
  convRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  currentUserId: string;
  attachments: ConversationAttachment[];
}): Promise<void> {
  if (attachments.length === 0) {
    return;
  }

  const freeAccessMode = await readSubscriptionConfigFreeAccessMode();
  if (freeAccessMode) {
    return;
  }

  const userSnap = await db.collection(COLLECTIONS.users).doc(currentUserId).get();
  const entitlements = getMessagingAttachmentEntitlements(
    userSnap.data()?.subscriptionPlan,
    freeAccessMode,
  );

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
    const data = doc.data() as Record<string, unknown>;
    if (data.deletedAt || data.isDeleted === true) {
      continue;
    }

    const rawAttachments = Array.isArray(data.attachments) ? data.attachments : [];
    for (const rawAttachment of rawAttachments) {
      const attachmentType = String((rawAttachment as Record<string, unknown>)?.type || "").trim();
      if (attachmentType === "image") {
        existingPhotos++;
      } else if (attachmentType === "audio") {
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

export function buildAttachmentMessageFallbackText(
  attachment: Pick<ConversationAttachment, "type" | "name">,
): string {
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

function sanitizeAttachmentText(value: unknown, maxLength: number): string {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function isAllowedDocumentAttachmentMimeType(mimeType: string): boolean {
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

export function buildProcessedConversationAttachmentPath({
  uid,
  conversationId,
  storagePath,
}: {
  uid: string;
  conversationId: string;
  storagePath: string;
}): string {
  const expectedPrefix = `messageAttachments/${uid}/${conversationId}/`;
  if (!storagePath.startsWith(expectedPrefix)) {
    throw new HttpsError("permission-denied", "Unauthorized storage path");
  }
  if (storagePath.includes("..") || storagePath.includes("\\") || storagePath.startsWith("/")) {
    throw new HttpsError("invalid-argument", "Invalid storage path");
  }

  const baseName = pathPosix.basename(storagePath).replace(/\.[^/.]+$/, "");
  return `${expectedPrefix}processed_${baseName}.webp`;
}

export const processConversationAttachmentPhoto = onCall(
  {
    ...MESSAGING_CALLABLE_OPTIONS,
    timeoutSeconds: 60,
    memory: "512MiB",
    cpu: 1,
    concurrency: 4,
    maxInstances: 20,
  },
  async (request) => {
    const uid = requireAuthUid(request);
    const conversationId = String(request.data?.conversationId || "").trim();
    const storagePath = String(request.data?.storagePath || "").trim();

    if (!conversationId || !storagePath) {
      throw new HttpsError("invalid-argument", "conversationId and storagePath are required");
    }

    await loadConversationForParticipant(conversationId, uid);

    const destinationPath = buildProcessedConversationAttachmentPath({
      uid,
      conversationId,
      storagePath,
    });
    const bucket = admin.storage().bucket();
    const sourceFile = bucket.file(storagePath);

    let sourceBuffer: Buffer;
    try {
      const [buffer] = await sourceFile.download();
      sourceBuffer = buffer;
    } catch {
      throw new HttpsError("not-found", "Source photo not found");
    }

    let outputBuffer: Buffer;
    let width = 0;
    let height = 0;
    try {
      const processed = await sharp(sourceBuffer)
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
    } catch {
      throw new HttpsError("internal", "Image processing failed");
    }

    const token = randomUUID();
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
    } catch {
      throw new HttpsError("internal", "Image upload failed");
    }

    try {
      await sourceFile.delete();
    } catch {
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
  },
);

export function sanitizeConversationAttachments(
  value: unknown,
  currentUserId: string,
  conversationId: string,
): ConversationAttachment[] {
  if (value == null) return [];
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "attachments must be an array");
  }
  if (value.length > 4) {
    throw new HttpsError("invalid-argument", "too many attachments");
  }

  return value.map((entry, index) => {
    if (!entry || typeof entry !== "object") {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} is invalid`);
    }
    const raw = entry as Record<string, unknown>;
    const type = sanitizeAttachmentText(raw.type, 24);
    if (type !== "image" && type !== "document" && type !== "audio") {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} type is invalid`);
    }

    const name = sanitizeAttachmentText(raw.name, 140) ||
      (type === "image" ? "Photo" : type === "audio" ? "Note vocale" : "Document");
    const url = String(raw.url ?? "").trim();
    const storagePath = String(raw.storagePath ?? "").trim();
    const mimeType = sanitizeAttachmentText(raw.mimeType, 120);
    const sizeBytes = Number(raw.sizeBytes || 0);
    let parsedUrl: URL;
    try {
      parsedUrl = new URL(url);
    } catch (_) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} url is invalid`);
    }

    if (parsedUrl.protocol !== "https:" ||
      !["firebasestorage.googleapis.com", "storage.googleapis.com"].includes(parsedUrl.hostname) ||
      !storagePath.startsWith(`messageAttachments/${currentUserId}/${conversationId}/`)) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} storage is invalid`);
    }
    if (storagePath.includes("..") || storagePath.includes("\\") || storagePath.startsWith("/")) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} storage path is invalid`);
    }
    if (!mimeType || !Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > 20 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} metadata is invalid`);
    }
    if (type === "image" && !mimeType.startsWith("image/")) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} must be an image`);
    }
    if (
      type === "image" &&
      (
        mimeType !== "image/webp" ||
        !storagePath.toLowerCase().endsWith(".webp") ||
        !name.toLowerCase().endsWith(".webp")
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        `attachment #${index + 1} image must be processed as WebP before sending`,
      );
    }
    if (type === "document" && !isAllowedDocumentAttachmentMimeType(mimeType)) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} document type is invalid`);
    }
    if (type === "audio" && !ALLOWED_AUDIO_ATTACHMENT_MIME_TYPES.has(mimeType)) {
      throw new HttpsError("invalid-argument", `attachment #${index + 1} audio type is invalid`);
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

export function mergeConversationParticipants(
  existingParticipants: string[],
  requiredParticipants: string[],
): string[] {
  return [...existingParticipants, ...requiredParticipants]
    .map((value) => String(value || "").trim())
    .filter(Boolean)
    .filter((value, index, all) => all.indexOf(value) === index)
    .sort();
}

function toDateOrNull(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "number" && Number.isFinite(value)) return new Date(value);
  return null;
}

export function computeUnreadCountAfterMessageDeletion({
  participants,
  unreadCount,
  lastReadAt,
  deletedSenderId,
  deletedCreatedAt,
}: {
  participants: string[];
  unreadCount: Record<string, unknown>;
  lastReadAt: Record<string, unknown>;
  deletedSenderId: string;
  deletedCreatedAt: Date | null;
}): Record<string, number> {
  const result: Record<string, number> = {};

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

type ConversationAccessResult = {
  allowed: boolean;
  reason: string;
  detectedFields: string[];
};

function canAccessConversation(
  data: Record<string, unknown>,
  uid: string,
  participants: string[],
  options: { isAdmin?: boolean } = {},
): ConversationAccessResult {
  const detectedFields: string[] = [];

  // (a) uid présent dans les participants canoniques (couvre participants, participantIds,
  //     participant_ids, userIds, memberIds, et les clés des maps participantNames, unreadCount, etc.)
  if (participants.includes(uid)) {
    detectedFields.push("participants");
    return { allowed: true, reason: "participants", detectedFields };
  }

  // Champs tableau supplémentaires non couverts par readConversationParticipants
  for (const field of ["users"] as const) {
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
    if ((participantsMap as Record<string, unknown>)[uid] === true) {
      return { allowed: true, reason: "participantsMap", detectedFields };
    }
  }

  // (b) Champs scalaires owner / assignee
  for (const field of ["createdBy", "ownerId", "requesterId", "userId", "adminId", "assigneeId"] as const) {
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

async function loadConversationForParticipant(
  conversationId: string,
  currentUserId: string,
  options: { isAdmin?: boolean } = {},
) {
  const convRef = db.collection(COLLECTIONS.conversations).doc(conversationId);
  const convSnap = await convRef.get();

  if (!convSnap.exists) {
    throw new HttpsError("not-found", "conversation not found");
  }

  const data = (convSnap.data() ?? {}) as Record<string, unknown>;
  const conversation = readConversationMirrorData(data, { conversationId });
  const participants = conversation.participants;

  const access = canAccessConversation(data, currentUserId, participants, { isAdmin: options.isAdmin });

  logger.info("conversation_access_check", {
    conversationId_len: conversationId.length,
    uid_len: currentUserId.length,
    isAdmin: options.isAdmin ?? false,
    detectedFields: access.detectedFields,
    allowedReason: access.reason,
  });

  if (!access.allowed) {
    throw new HttpsError("permission-denied", "not allowed to access this conversation");
  }

  return { convRef, data, participants, conversation };
}

export const ensureOfferConversation = onCall(MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const listingId = String(request.data?.listingId || request.data?.offerId || "").trim();
  const otherUserId = String(request.data?.otherUserId || "").trim();

  if (!listingId || !otherUserId) {
    throw new HttpsError("invalid-argument", "listingId and otherUserId are required");
  }

  if (currentUserId == otherUserId) {
    throw new HttpsError("failed-precondition", "cannot create a conversation with yourself");
  }

  const { data: offerData, source: offerSource } = await loadOfferLikeSnapshot(listingId);
  const offerOwnerId = readOfferOwnerId(offerData);
  if (!offerOwnerId) {
    throw new HttpsError("failed-precondition", `${offerSource} owner is missing`);
  }
  if (offerOwnerId != otherUserId) {
    throw new HttpsError("permission-denied", `conversation target does not match ${offerSource} owner`);
  }

  const offerTitle = String(
    offerData.listingTitle ||
    offerData.offerTitle ||
    offerData.title ||
    request.data?.listingTitle ||
    request.data?.offerTitle ||
    "",
  ).trim();
  if (!offerTitle) {
    throw new HttpsError("failed-precondition", "offer title is missing");
  }

  const [currentUserSnap, otherUserSnap] = await Promise.all([
    db.collection(COLLECTIONS.users).doc(currentUserId).get(),
    db.collection(COLLECTIONS.users).doc(otherUserId).get(),
  ]);

  const currentUserName = readUserDisplayName(
    currentUserSnap.data() as Record<string, unknown> | undefined,
    request.auth?.token?.name,
    request.auth?.token?.email,
    currentUserId,
  );
  const otherUserName = readUserDisplayName(
    otherUserSnap.data() as Record<string, unknown> | undefined,
    offerData.advertiserName,
    otherUserId,
  );

  const participantNames: Record<string, string> = {
    [currentUserId]: currentUserName,
    [otherUserId]: otherUserName,
  };

  const convCol = db.collection(COLLECTIONS.conversations);
  const existingDocs = await findConversationSnapshotsForParticipant(currentUserId, listingId);

  for (const doc of existingDocs) {
    const docData = doc.data() as Record<string, unknown>;
    const conversation = readConversationMirrorData(docData, { conversationId: doc.id });
    if (!conversation.participants.includes(otherUserId)) continue;

    const normalizedParticipants = mergeConversationParticipants(
      conversation.participants,
      [currentUserId, otherUserId],
    );

    if (isConversationBlocked(docData)) {
      throw new HttpsError("failed-precondition", "conversation is blocked");
    }

    if (shouldForkConversationThread(normalizedParticipants, conversation.deletedBy)) {
      continue;
    }

    const archivedBy = {
      ...conversation.archivedBy,
      [currentUserId]: false,
    };
    const blockedBy = conversation.blockedBy;

    await doc.ref.set(
      buildConversationMirrorFields({
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
        status: computeConversationStatus(normalizedParticipants, archivedBy, blockedBy),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      { merge: true },
    );

    return {
      ok: true,
      conversationId: doc.id,
      offerTitle,
    };
  }

  const conversationId = canonicalConversationId({ listingId, currentUserId, otherUserId });
  const participants = [currentUserId, otherUserId].sort();
  const matchingConversationExists = existingDocs.some((doc) => {
    const docData = doc.data() as Record<string, unknown>;
    const conversation = readConversationMirrorData(docData, { conversationId: doc.id });
    return conversation.participants.includes(otherUserId);
  });
  const targetConversationId = matchingConversationExists
    ? buildForkedConversationThreadId(conversationId)
    : conversationId;
  const convRef = convCol.doc(targetConversationId);

  if (targetConversationId != conversationId) {
    await convRef.set(
      buildConversationMirrorFields({
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
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: "",
        lastSenderId: "",
        lastSenderName: "",
        messageCount: 0,
        unreadCount: {
          [currentUserId]: 0,
          [otherUserId]: 0,
        },
      }),
      { merge: false },
    );

    return {
      ok: true,
      conversationId: convRef.id,
      offerTitle,
    };
  }

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(convRef);
    if (snap.exists) {
      const data = (snap.data() ?? {}) as Record<string, unknown>;
      const conversation = readConversationMirrorData(data, { conversationId: convRef.id });
      const normalizedParticipants = mergeConversationParticipants(conversation.participants, participants);

      const archivedBy = {
        ...conversation.archivedBy,
        [currentUserId]: false,
      };
      const blockedBy = conversation.blockedBy;

      transaction.set(
        convRef,
        buildConversationMirrorFields({
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
          status: computeConversationStatus(normalizedParticipants, archivedBy, blockedBy),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
        { merge: true },
      );
      return;
    }

    transaction.set(
      convRef,
      buildConversationMirrorFields({
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
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: "",
        lastSenderId: "",
        lastSenderName: "",
        messageCount: 0,
        unreadCount: {
          [currentUserId]: 0,
          [otherUserId]: 0,
        },
      }),
    );
  });

  return {
    ok: true,
    conversationId,
    listingId,
    offerTitle,
  };
});

export const sendConversationMessage = onCall(HOT_MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();
  const text = sanitizeMessageText(request.data?.text);
  const attachments = sanitizeConversationAttachments(request.data?.attachments, currentUserId, conversationId);
  const firstAttachment = attachments[0];
  const messageText = text || (firstAttachment
    ? buildAttachmentMessageFallbackText(firstAttachment)
    : "");

  if (!conversationId || !messageText) {
    throw new HttpsError("invalid-argument", "conversationId and text or attachment are required");
  }

  if (messageText.length > 4000) {
    throw new HttpsError("invalid-argument", "message is too long");
  }

  const canSend = await canProceedRateLimited(
    "msg_send",
    `${currentUserId}:${conversationId}`,
    MESSAGE_SEND_LIMIT,
    MESSAGE_SEND_WINDOW_MS,
  );
  if (!canSend) {
    throw new HttpsError("resource-exhausted", "too many messages sent too quickly");
  }

  const { convRef } = await loadConversationForParticipant(conversationId, currentUserId);
  await enforceMessagingAttachmentEntitlements({
    convRef,
    currentUserId,
    attachments,
  });

  const moderationMode = await loadMessagingModerationMode();
  let messageModeration = shouldModerateSynchronouslyBeforeSend(moderationMode)
    ? await evaluateMessagingModeration({
      mode: moderationMode,
      text: messageText,
      attachments,
    })
    : buildPendingMessagingModeration(moderationMode);

  if (shouldModerateSynchronouslyBeforeSend(moderationMode) && messageModeration.status !== "approved") {
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
    const latestData = latestMessageDoc.data() as Record<string, unknown>;
    const latestSenderId = String(latestData.senderId || "").trim();
    const latestText = sanitizeMessageText(latestData.text);
    const latestCreatedAt = toDateOrNull(latestData.createdAt);
    if (
      attachments.length === 0 &&
      latestSenderId === currentUserId &&
      latestText === messageText &&
      latestCreatedAt != null &&
      Date.now() - latestCreatedAt.getTime() <= DUPLICATE_MESSAGE_WINDOW_MS
    ) {
      return {
        ok: true,
        deduplicated: true,
        messageId: latestMessageDoc.id,
      };
    }
  }

  const senderUserSnap = await db.collection(COLLECTIONS.users).doc(currentUserId).get();
  const senderName = readUserDisplayName(
    senderUserSnap.data() as Record<string, unknown> | undefined,
    request.auth?.token?.name,
    request.auth?.token?.email,
    currentUserId,
  );

  const messageRef = convRef.collection("messages").doc();
  let participantsToRefresh: string[] = [];
  let effectiveConversationId = conversationId;
  let effectiveMessageId = messageRef.id;

  await db.runTransaction(async (transaction) => {
    const convSnap = await transaction.get(convRef);

    if (!convSnap.exists) {
      throw new HttpsError("not-found", "conversation not found");
    }

    const data = (convSnap.data() ?? {}) as Record<string, unknown>;
    const conversation = readConversationMirrorData(data, { conversationId });
    const participants = conversation.participants;
    assertConversationParticipantAccess(participants, currentUserId);

    if (isConversationBlocked(data)) {
      throw new HttpsError("failed-precondition", "conversation is blocked");
    }

    const isFirstMessage = readConversationMessageCount(data) === 0;

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
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      senderId: currentUserId,
      sender_id: currentUserId,
      senderName,
      sender_name: senderName,
      isFirstMessage,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
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
      const forkedConvRef = db.collection(COLLECTIONS.conversations).doc(forkedConversationId);
      const forkedMessageRef = forkedConvRef.collection("messages").doc();
      const retiredArchivedBy = {
        ...archivedBy,
        [currentUserId]: true,
      };
      const retiredDeletedBy = {
        ...deletedBy,
        [currentUserId]: true,
      };
      const freshArchivedBy = Object.fromEntries(
        participants.map((participantId) => [participantId, false]),
      );
      const freshDeletedBy = Object.fromEntries(
        participants.map((participantId) => [participantId, false]),
      );
      const freshBlockedBy = Object.fromEntries(
        participants.map((participantId) => [participantId, false]),
      );
      const freshUnreadCount = Object.fromEntries(
        participants.map((participantId) => [
          participantId,
          participantId == currentUserId ? 0 : admin.firestore.FieldValue.increment(1),
        ]),
      );

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
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        senderId: currentUserId,
        sender_id: currentUserId,
        senderName,
        sender_name: senderName,
        isFirstMessage: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(
        forkedConvRef,
        buildConversationMirrorFields({
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
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessage: messageText,
          lastSenderId: currentUserId,
          lastSenderName: senderName,
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          messageCount: 1,
        }),
        { merge: false },
      );

      transaction.update(
        convRef,
        buildConversationMirrorFields({
          ...conversation,
          participants,
          archivedBy: retiredArchivedBy,
          deletedBy: retiredDeletedBy,
          blockedBy: conversation.blockedBy,
          unreadCount: {
            ...conversation.unreadCount,
            [currentUserId]: 0,
          },
          status: computeConversationStatus(participants, retiredArchivedBy, conversation.blockedBy),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
      );

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
        : admin.firestore.FieldValue.increment(1);
    }

    transaction.update(
      convRef,
      buildConversationMirrorFields({
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
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        messageCount: admin.firestore.FieldValue.increment(1),
      }),
    );
    participantsToRefresh = participants;
  });

  await Promise.all(participantsToRefresh.map((participantId) => refreshUnreadMessageCount(participantId)));

  return {
    ok: true,
    messageId: effectiveMessageId,
    conversationId: effectiveConversationId,
  };
});

export const markConversationRead = onCall(HOT_MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const roles = extractRolesFromAuthToken(request.auth?.token as Record<string, unknown> | undefined);
  const isAdmin = roles.includes("admin") || roles.includes("superadmin");

  const { convRef, conversation } = await loadConversationForParticipant(conversationId, currentUserId, { isAdmin });
  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      unreadCount: {
        ...conversation.unreadCount,
        [currentUserId]: 0,
      },
      lastReadAt: {
        ...conversation.lastReadAt,
        [currentUserId]: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  await refreshUnreadMessageCount(currentUserId);

  return { ok: true };
});

export const archiveConversation = onCall(MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
  const archivedBy = {
    ...conversation.archivedBy,
    [currentUserId]: true,
  };
  const blockedBy = conversation.blockedBy;

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  return { ok: true };
});

export const unarchiveConversation = onCall(MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
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

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      deletedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  return { ok: true };
});

export const blockConversation = onCall(MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
  const archivedBy = conversation.archivedBy;
  const blockedBy = {
    ...conversation.blockedBy,
    [currentUserId]: true,
  };

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  return { ok: true };
});

export const unblockConversation = onCall(MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, data, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);
  if (!isConversationFlagEnabledForUser(data, "blockedBy", currentUserId)) {
    return { ok: true };
  }

  const archivedBy = readConversationFlagMap(data, "archivedBy");
  const blockedBy = {
    ...conversation.blockedBy,
    [currentUserId]: false,
  };

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  return { ok: true };
});

export const adminUnblockConversation = onCall(ADMIN_MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  requireAdminAccess(request);

  const conversationId = String(request.data?.conversationId || "").trim();
  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const { convRef, data, participants, conversation } = await loadConversationForParticipant(
    conversationId,
    currentUserId,
    { isAdmin: true },
  );
  const archivedBy = readConversationFlagMap(data, "archivedBy");
  const blockedBy: Record<string, boolean> = {};
  for (const participantId of participants) {
    blockedBy[participantId] = false;
  }

  await convRef.update(
    buildConversationMirrorFields({
      ...conversation,
      participants,
      archivedBy,
      blockedBy,
      status: computeConversationStatus(participants, archivedBy, blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  );

  logger.info("admin_unblocked_conversation", {
    conversationId_len: conversationId.length,
    adminUid_len: currentUserId.length,
    participantCount: participants.length,
  });

  return { ok: true };
});

export const deleteConversation = onCall(MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  // --- Standard path: full access check + mirror update ---
  try {
    const { convRef, data, participants, conversation } = await loadConversationForParticipant(
      conversationId,
      currentUserId,
    );
    const notificationUserIds = await deleteNotificationsForConversation(
      conversationId,
      currentUserId,
    );
    const archivedBy = readConversationFlagMap(data, "archivedBy");
    const deletedBy = readConversationFlagMap(data, "deletedBy");
    const blockedBy = readConversationFlagMap(data, "blockedBy");
    const unreadCount = {
      ...conversation.unreadCount,
      [currentUserId]: 0,
    };

    archivedBy[currentUserId] = true;
    deletedBy[currentUserId] = true;

    await convRef.update(
      buildConversationMirrorFields({
        ...conversation,
        participants,
        archivedBy,
        deletedBy,
        blockedBy,
        unreadCount,
        status: computeConversationStatus(participants, archivedBy, blockedBy),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    );

    await refreshUnreadMessageCount(currentUserId);
    await Promise.all(
      Array.from(notificationUserIds, (userId) => refreshUnreadNotificationCount(userId)),
    );

    return { ok: true };
  } catch (err) {
    // --- Permissive fallback: conversation exists but participant data is missing ---
    // Applies to old-format conversations (test messages, deleted-account participants).
    // Safe because deleteConversation is a soft-delete that only marks visibility
    // for the requesting user without exposing or modifying data for others.
    const isPermissionDenied =
      err instanceof HttpsError && err.code === "permission-denied";
    if (!isPermissionDenied) {
      throw err;
    }

    const convRef = db.collection(COLLECTIONS.conversations).doc(conversationId);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
      throw new HttpsError("not-found", "conversation not found");
    }

    logger.info("deleteConversation_permissive_fallback", {
      conversationId_len: conversationId.length,
      uid_len: currentUserId.length,
    });

    await convRef.update({
      [`deletedBy.${currentUserId}`]: true,
      [`archivedBy.${currentUserId}`]: true,
      [`unreadCount.${currentUserId}`]: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await refreshUnreadMessageCount(currentUserId);

    return { ok: true, fallback: true };
  }
});

export const deleteConversationMessage = onCall(MESSAGING_CALLABLE_OPTIONS, async (request) => {
  const currentUserId = requireAuthUid(request);
  const conversationId = String(request.data?.conversationId || "").trim();
  const messageId = String(request.data?.messageId || "").trim();

  if (!conversationId || !messageId) {
    throw new HttpsError("invalid-argument", "conversationId and messageId are required");
  }

  const { convRef, participants, conversation } = await loadConversationForParticipant(conversationId, currentUserId);

  const messageRef = convRef.collection("messages").doc(messageId);
  const messageSnap = await messageRef.get();

  if (!messageSnap.exists) {
    throw new HttpsError("not-found", "message not found");
  }

  const messageData = (messageSnap.data() ?? {}) as Record<string, unknown>;
  const senderId = String(messageData.senderId || messageData.sender_id || "").trim();
  const deletedCreatedAt = toDateOrNull(messageData.createdAt || messageData.created_at);

  if (senderId !== currentUserId) {
    throw new HttpsError("permission-denied", "you can only delete your own messages");
  }

  // Soft-delete: clear content and mark as deleted so a placeholder appears in the thread.
  await messageRef.update({
    text: "",
    body: "",
    attachments: [],
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    deletedBy: currentUserId,
  });

  // Delete Storage files that were attached (best-effort, errors are ignored).
  const rawAttachments = Array.isArray(messageData.attachments) ? messageData.attachments : [];
  const storagePaths: string[] = [];
  for (const att of rawAttachments) {
    const sp = String((att as Record<string, unknown>).storagePath || "").trim();
    if (sp) storagePaths.push(sp);
  }
  if (storagePaths.length > 0) {
    const bucket = admin.storage().bucket();
    await Promise.allSettled(storagePaths.map((sp) => bucket.file(sp).delete()));
  }

  const messagesRef = convRef.collection("messages");
  const [latestMessageSnap, messageCountSnap] = await Promise.all([
    messagesRef.orderBy("createdAt", "desc").limit(1).get(),
    messagesRef.count().get(),
  ]);
  const latestRaw = latestMessageSnap.docs[0]?.data() as Record<string, unknown> | undefined;
  // Show a placeholder text in the conversation list if the latest message was deleted.
  const latestMessage = (latestRaw
    ? { ...latestRaw, text: latestRaw.deletedAt ? "Message supprimé" : (latestRaw.text ?? latestRaw.body) }
    : undefined) as Record<string, unknown> | undefined;
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

  await convRef.set(
    buildConversationMirrorFields({
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
      status: computeConversationStatus(participants, archivedBy, conversation.blockedBy),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    { merge: true },
  );

  await Promise.all(participants.map((participantId) => refreshUnreadMessageCount(participantId)));

  return { ok: true };
});