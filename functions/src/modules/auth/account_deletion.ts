import admin from "../../core/firebase_admin_compat";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION, STRIPE_SECRET_KEY } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { archiveUserListings } from "./account_deletion_cleanup";

const RECENT_AUTH_MAX_AGE_SECONDS = 10 * 60;
const BATCH_WRITE_LIMIT = 400;

type DocumentReference = FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;

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

async function deleteUserOwnedDocuments(uid: string): Promise<number> {
  const exactRefs: DocumentReference[] = [
    db.collection("notification_preferences").doc(uid),
    db.collection("toolbox_journey_index").doc(uid),
  ];

  const querySpecs = [
    ["favorites", "userId"],
    ["notifications", "userId"],
    ["push_tokens", "userId"],
    ["listingDrafts", "ownerId"],
    ["parcours", "userId"],
    ["parcours", "ownerId"],
    ["toolbox_journeys", "userId"],
    ["toolbox_journeys", "ownerId"],
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

async function anonymizeConversations(uid: string): Promise<number> {
  const snapshot = await db
    .collection("conversations")
    .where("participantIds", "array-contains", uid)
    .get();

  let batch = db.batch();
  let pending = 0;
  let updated = 0;

  for (const doc of snapshot.docs) {
    batch.set(
      doc.ref,
      {
        [`participantNames.${uid}`]: "Utilisateur supprimé",
        [`deletedBy.${uid}`]: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    pending += 1;
    updated += 1;

    if (pending >= BATCH_WRITE_LIMIT) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }

  if (pending > 0) await batch.commit();
  return updated;
}

async function deleteUserStorage(uid: string): Promise<void> {
  const bucket = admin.storage().bucket();
  const prefixes = [
    `profilePhotos/${uid}/`,
    `listingDrafts/${uid}/`,
    `messageAttachments/${uid}/`,
    `stt_streaming/${uid}/`,
  ];

  await Promise.all(
    prefixes.map((prefix) => bucket.deleteFiles({ prefix, force: true })),
  );

  const [sttFiles] = await bucket.getFiles({ prefix: `stt/${uid}_` });
  await Promise.all(
    sttFiles.map((file) => file.delete({ ignoreNotFound: true })),
  );
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
    const userRef = db.collection("users").doc(uid);
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

    const [deletedDocuments, anonymizedConversations, archivedListings] =
      await Promise.all([
        deleteUserOwnedDocuments(uid),
        anonymizeConversations(uid),
        archiveUserListings(uid),
      ]);
    await deleteUserStorage(uid);

    await userRef.set(
      {
        accountStatus: "deleted",
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        email: null,
        displayName: "Utilisateur supprimé",
        fullName: null,
        firstName: null,
        lastName: null,
        pseudo: null,
        phoneNumber: null,
        photoUrl: null,
        photoURL: null,
        pendingEmail: null,
        stripeCustomerId: null,
        stripe_customer_id: null,
        stripeSubscriptionId: null,
        stripe_subscription_id: null,
        stripePriceId: null,
        stripe_price_id: null,
        subscriptionPlan: "free",
        subscriptionStatus: "canceled",
        deletionCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    try {
      await admin.auth().revokeRefreshTokens(uid);
      await admin.auth().deleteUser(uid);
    } catch (error) {
      const code = String((error as { code?: string }).code || "");
      if (code !== "auth/user-not-found") throw error;
    }

    logger.info("ACCOUNT_DELETION_COMPLETED", {
      uid,
      deletedDocuments,
      anonymizedConversations,
      archivedListings,
      stripeSubscriptionCanceled: Boolean(subscriptionId),
    });

    return {
      ok: true,
      deletedDocuments,
      anonymizedConversations,
      archivedListings,
    };
  },
);
