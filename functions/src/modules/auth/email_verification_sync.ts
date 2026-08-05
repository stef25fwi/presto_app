import admin from "../../core/firebase_admin_compat";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";

export const syncMyEmailVerification = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 30,
  },
  async (request) => {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
      throw new HttpsError("unauthenticated", "authentication required");
    }

    const userRecord = await admin.auth().getUser(uid);
    await db.collection(COLLECTIONS.users).doc(uid).set(
      {
        email: userRecord.email || null,
        emailVerified: userRecord.emailVerified === true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      ok: true,
      emailVerified: userRecord.emailVerified === true,
    };
  },
);
