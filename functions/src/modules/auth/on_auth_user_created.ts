import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { PROJECT_REGION } from "../../config/env";

/**
 * Auth trigger v1 — crée le document `users/{uid}` dès qu'un compte
 * Firebase Auth est provisionné (avant même la première connexion côté client).
 *
 * Complémentaire de `onUserCreated` (trigger Firestore sur le doc user).
 */
export const onAuthUserCreated = functionsV1
  .region(PROJECT_REGION)
  .auth.user()
  .onCreate(async (user) => {
    const uid = user.uid;
    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .set(
        {
          uid,
          email: user.email || null,
          displayName: user.displayName || null,
          photoURL: user.photoURL || null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  });
