import admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { COLLECTIONS } from "../../shared/constants";
import { extractRolesFromAuthToken, requireAnyRole } from "../marketplace/services/roles";
import { sendBroadcastPush } from "./push";

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

const BROADCAST_DEFAULT_TITLE = "Notification test";
const BROADCAST_DEFAULT_BODY = "Ceci est une notification test envoyée à tous les utilisateurs.";

export const broadcastTestNotification = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (request) => {
    const token = request.auth?.token as Record<string, unknown> | undefined;
    if (!token) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const roles = extractRolesFromAuthToken(token);
    requireAnyRole(roles, ["admin", "superadmin"], "Admin access required");

    const title = (String(request.data?.title || "").trim() || BROADCAST_DEFAULT_TITLE).slice(0, 120);
    const body = (String(request.data?.body || "").trim() || BROADCAST_DEFAULT_BODY).slice(0, 500);

    const result = await sendBroadcastPush({
      title,
      body,
      channelId: "ilipresto_activity",
      collapseKey: "admin_broadcast_test",
      data: { kind: "admin_broadcast_test" },
    });

    logger.info("admin_broadcast_test_sent", {
      actor: request.auth?.uid ?? "unknown",
      ...result,
    });

    return { ok: true, ...result };
  },
);

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