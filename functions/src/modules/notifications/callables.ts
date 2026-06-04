import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { COLLECTIONS } from "../../shared/constants";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "authentication required");
  }
  return uid;
}

function sanitizeTokenDocId(token: string): string {
  return token.replaceAll("/", "_");
}

export const registerPushToken = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const userId = requireAuthUid(request);
  const token = String(request.data?.token || "").trim();
  const platform = String(request.data?.platform || "unknown").trim().slice(0, 32);

  if (token.length < 20) {
    throw new HttpsError("invalid-argument", "invalid push token");
  }

  const docId = sanitizeTokenDocId(token);
  const tokenRef = db
    .collection(COLLECTIONS.users)
    .doc(userId)
    .collection(COLLECTIONS.pushTokens)
    .doc(docId);

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(tokenRef);
    transaction.set(tokenRef, {
      token,
      uid: userId,
      userId,
      platform,
      enabled: true,
      ...(snap.exists ? {} : { createdAt: admin.firestore.FieldValue.serverTimestamp() }),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  logger.info("push_token_registered", {
    userId,
    tokenId: docId,
    platform,
    appCheck: request.app != null,
  });

  return { ok: true, tokenId: docId };
});

export const unregisterPushToken = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const userId = requireAuthUid(request);
  const token = String(request.data?.token || "").trim();

  if (!token) {
    throw new HttpsError("invalid-argument", "token is required");
  }

  const docId = sanitizeTokenDocId(token);
  await db
    .collection(COLLECTIONS.users)
    .doc(userId)
    .collection(COLLECTIONS.pushTokens)
    .doc(docId)
    .delete();

  return { ok: true };
});