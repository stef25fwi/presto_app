import admin from "../../core/firebase_admin_compat";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { COLLECTIONS } from "../../shared/constants";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

// Firebase Auth has no concept of a "linked but unverified" phone number —
// user.phoneNumber is only ever populated after a successful SMS code
// confirmation. Reading it via the Admin SDK (rather than trusting a client
// claim or ID token) is what makes this callable authoritative.
export const confirmPhoneVerified = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const uid = requireAuthUid(request);

    const userRecord = await admin.auth().getUser(uid);
    const phoneNumber = String(userRecord.phoneNumber || "").trim();
    if (!phoneNumber) {
      throw new HttpsError(
        "failed-precondition",
        "No verified phone number is linked to this account",
      );
    }

    await db.collection(COLLECTIONS.users).doc(uid).set(
      {
        phone: phoneNumber,
        phoneVerified: true,
        phoneVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logger.info("account_phone_verified", { uid });

    return { ok: true, phone: phoneNumber };
  },
);
