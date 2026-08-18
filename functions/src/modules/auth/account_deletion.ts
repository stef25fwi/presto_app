import admin from "../../core/firebase_admin_compat";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION, STRIPE_SECRET_KEY } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES } from "../messaging/participants";
import { archiveUserListings } from "./account_deletion_cleanup";

const RECENT_AUTH_MAX_AGE_SECONDS = 10 * 60;
const BATCH_WRITE_LIMIT = 400;
const DELETED_USER_LABEL = "Utilisateur supprimé";
const DELETED_MESSAGE_LABEL = "Message supprimé";

type DocumentReference = FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
type ConversationDocument = FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>;

export interface AccountDeletionResult {
  ok: true;
  deletedDocuments: number;
  deletedUserTreeDocuments: number;
  anonymizedConversations: number;
  deletedMessages: number;
  archivedListings: number;
  deletedFiles: number;
}

function requireRecentAuthenticatedUid(request: {
  auth?: { uid?: string; token?: Record<string, unknown> };
}): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "authentication required");
  }

  const authTime = Number(request.auth?.token?.auth_time || 0);
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (
    !Number.isFinite(authTime) ||
    authTime <= 0 ||
    nowSeconds - authTime > RECENT_AUTH_MAX_AGE_SECONDS
  ) {
    throw new HttpsError(
      "failed-precondition",
      "recent authentication required",
      { reason: "recent_authentication_required" },
    );
  }

  return uid;
}

async function cancelStripeSubscription(subscriptionId: string): Promise<void> {
  const normalizedId = subscriptionId.trim();
  if (!normalizedId) return;

  const secret = STRIPE_SECRET_KEY.value().trim();
  if (!secret) {
    throw new HttpsError("failed-precondition", "Stripe is not configured");
  }

  const response = await fetch(
    `https://api.stripe.com/v1/subscriptions/${encodeURIComponent(normalizedId)}`,
    {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${secret}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    },
  );

  if (response.ok || response.status === 404) return;

  const payload = await response.json().catch(() => ({})) as {
    error?: { message?: string };
  };
  throw new HttpsError(
    "internal",
    payload.error?.message || `Stripe cancellation failed (${response.status})`,
  );
}

async function commitDeletes(refs: Iterable<DocumentReference>): Promise<number> {
  let batch = db.batch();
  let pending = 0;
  let deleted = 0;

  for (const ref of refs) {
    batch.delete(ref);
    pending += 1;
    deleted += 1;

    if (pending >= BATCH_WRITE_LIMIT) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }

  if (pending > 0) await batch.commit();
  return deleted;
}

async function queryRefs(
  collectionName: string,
  field: string,
  uid: string,
): Promise<DocumentReference[]> {
  const snapshot = await db.collection(collectionName).where(field, "==", uid).get();
  return snapshot.docs.map((doc) => doc.ref);
}

async function deleteDocumentTree(ref: DocumentReference): Promise<number> {
  let deleted = 0;
  const subcollections = await ref.listCollections();
  for (const subcollection of subcollections) {
    const snapshot = await subcollection.get();
    for (const doc of snapshot.docs) {
      deleted += await deleteDocumentTree(doc.ref);
    }
  }
  await ref.delete();
  return deleted + 1;
}

async function deleteUserOwnedDocuments(uid: string): Promise<number> {
  const exactRefs: DocumentReference[] = [
    db.collection("notification_preferences").doc(uid),
    db.collection("toolbox_journey_index").doc(uid),
    db.collection("pro_profiles").doc(uid),
    db.collection("pros").doc(uid),
    db.collection("pro_verification_rate_limits").doc(uid),
    db.collection("subscriptions").doc(uid),
    db.collection("profiles").doc(uid),
    db.collection("user_profiles").doc(uid),
  ];

  const querySpecs = [
    ["favorites", "userId"],
    ["notifications", "userId"],
    ["push_tokens", "userId"],
    ["listingDrafts", "ownerId"],
    ["listing_drafts", "ownerId"],
    ["listing_drafts", "userId"],
    ["parcours", "userId"],
    ["parcours", "ownerId"],
    ["toolbox_journeys", "userId"],
    ["toolbox_journeys", "ownerId"],
    ["saved_searches", "userId"],
    ["saved_searches", "ownerId"],
    ["pro_verification_logs", "uid"],
    ["listingPhotoReviews", "ownerId"],
    ["listingPhotoReviews", "userId"],
    ["reviews", "reviewerId"],
    ["reviews", "reviewedUserId"],
    ["messages", "senderId"],
    ["messages", "sender_id"],
    ["conversation_messages", "senderId"],
    ["conversation_messages", "sender_id"],
    ["offers", "ownerId"],
    ["offers", "userId"],
    ["offers", "uid"],
  ] as const;

  const queriedRefs = await Promise.all(
    querySpecs.map(([collectionName, field]) => queryRefs(collectionName, field, uid)),
  );

  const byPath = new Map<string, DocumentReference>();
  for (const ref of [...exactRefs, ...queriedRefs.flat()]) {
    byPath.set(ref.path, ref);
  }

  return commitDeletes(byPath.values());
}

async function loadUserConversations(uid: string): Promise<ConversationDocument[]> {
  const snapshots = await Promise.all(
    CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.map((field) =>
      db.collection("conversations").where(field, "array-contains", uid).get(),
    ),
  );

  const byId = new Map<string, ConversationDocument>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      byId.set(doc.id, doc);
    }
  }
  return Array.from(byId.values());
}

async function deleteConversationMessages(
  conversation: ConversationDocument,
  uid: string,
): Promise<number> {
  const messages = conversation.ref.collection("messages");
  const snapshots = await Promise.all([
    messages.where("senderId", "==", uid).get(),
    messages.where("sender_id", "==", uid).get(),
  ]);

  const byPath = new Map<string, DocumentReference>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      byPath.set(doc.ref.path, doc.ref);
    }
  }
  return commitDeletes(byPath.values());
}

async function anonymizeConversations(uid: string): Promise<{
  updated: number;
  deletedMessages: number;
}> {
  const conversations = await loadUserConversations(uid);
  let batch = db.batch();
  let pending = 0;
  let updated = 0;
  let deletedMessages = 0;

  for (const doc of conversations) {
    deletedMessages += await deleteConversationMessages(doc, uid);

    const data = (doc.data() ?? {}) as Record<string, unknown>;
    const lastSenderId = String(data.lastSenderId ?? data.last_sender_id ?? "").trim();
    const patch: Record<string, unknown> = {
      [`participantNames.${uid}`]: DELETED_USER_LABEL,
      [`participant_names.${uid}`]: DELETED_USER_LABEL,
      [`deletedBy.${uid}`]: true,
      [`deleted_by.${uid}`]: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (lastSenderId === uid) {
      patch.lastMessage = DELETED_MESSAGE_LABEL;
      patch.last_message = DELETED_MESSAGE_LABEL;
      patch.lastSenderId = "";
      patch.last_sender_id = "";
      patch.lastSenderName = DELETED_USER_LABEL;
      patch.last_sender_name = DELETED_USER_LABEL;
    }

    batch.set(doc.ref, patch, { merge: true });
    pending += 1;
    updated += 1;

    if (pending >= BATCH_WRITE_LIMIT) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }

  if (pending > 0) await batch.commit();
  return { updated, deletedMessages };
}

async function listingIdsOwnedBy(uid: string): Promise<string[]> {
  const snapshot = await db.collection("listings").where("ownerId", "==", uid).get();
  return snapshot.docs.map((doc) => doc.id);
}

async function deleteUserStorage(uid: string): Promise<number> {
  const bucket = admin.storage().bucket();
  const listingIds = await listingIdsOwnedBy(uid);
  const prefixes = [
    `profilePhotos/${uid}/`,
    `listingDrafts/${uid}/`,
    `listings/${uid}/`,
    `messageAttachments/${uid}/`,
    `offers_raw/${uid}/`,
    `offers/${uid}/`,
    `stt_streaming/${uid}/`,
    ...listingIds.flatMap((listingId) => [
      `moderation_review/${listingId}/`,
      `rejected_ad_images/${listingId}/`,
    ]),
  ];

  let deletedFiles = 0;
  await Promise.all(
    prefixes.map(async (prefix) => {
      const [files] = await bucket.getFiles({ prefix });
      deletedFiles += files.length;
      await Promise.all(
        files.map((file) => file.delete({ ignoreNotFound: true })),
      );
    }),
  );

  const [sttFiles] = await bucket.getFiles({ prefix: `stt/${uid}_` });
  deletedFiles += sttFiles.length;
  await Promise.all(
    sttFiles.map((file) => file.delete({ ignoreNotFound: true })),
  );
  return deletedFiles;
}

export async function executeAccountDeletion(uid: string): Promise<AccountDeletionResult> {
  const normalizedUid = uid.trim();
  if (!normalizedUid) {
    throw new HttpsError("invalid-argument", "uid is required");
  }

  const userRef = db.collection("users").doc(normalizedUid);
  const userSnapshot = await userRef.get();
  const userData = userSnapshot.data() || {};
  const subscriptionId = String(
    userData.stripeSubscriptionId || userData.stripe_subscription_id || "",
  ).trim();

  await userRef.set(
    {
      accountStatus: "deletion_processing",
      deletionRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await cancelStripeSubscription(subscriptionId);

  const [deletedDocuments, conversationCleanup, archivedListings] =
    await Promise.all([
      deleteUserOwnedDocuments(normalizedUid),
      anonymizeConversations(normalizedUid),
      archiveUserListings(normalizedUid),
    ]);

  const deletedFiles = await deleteUserStorage(normalizedUid);

  // Efface aussi toutes les sous-collections du profil utilisateur
  // (notamment rateLimits/phoneVerification) avant de supprimer le document.
  const deletedUserTreeDocuments = await deleteDocumentTree(userRef);

  try {
    await admin.auth().revokeRefreshTokens(normalizedUid);
    await admin.auth().deleteUser(normalizedUid);
  } catch (error) {
    const code = String((error as { code?: string }).code || "");
    if (code !== "auth/user-not-found") throw error;
  }

  const result: AccountDeletionResult = {
    ok: true,
    deletedDocuments,
    deletedUserTreeDocuments,
    anonymizedConversations: conversationCleanup.updated,
    deletedMessages: conversationCleanup.deletedMessages,
    archivedListings,
    deletedFiles,
  };

  logger.info("ACCOUNT_DELETION_COMPLETED", {
    uid: normalizedUid,
    ...result,
    stripeSubscriptionCanceled: Boolean(subscriptionId),
  });

  return result;
}

export const requestAccountDeletion = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    secrets: [STRIPE_SECRET_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
    maxInstances: 10,
  },
  async (request) => {
    const uid = requireRecentAuthenticatedUid(request);
    return executeAccountDeletion(uid);
  },
);
