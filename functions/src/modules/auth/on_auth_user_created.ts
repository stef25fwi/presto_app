import * as functionsV1 from "firebase-functions/v1";
import admin from "../../core/firebase_admin_compat";
import { PROJECT_REGION } from "../../config/env";

/**
 * Auth trigger v1 — garantit un document `users/{uid}` canonique dès qu'un
 * compte Firebase Auth est provisionné.
 *
 * Le trigger utilise une transaction et `merge` pour couvrir la course où le
 * client écrit ses champs de profil avant la fin du trigger Auth. Les champs
 * d'autorité (rôle, abonnement, vérifications et createdAt) restent toujours
 * définis par l'Admin SDK.
 */
export const onAuthUserCreated = functionsV1
  .region(PROJECT_REGION)
  .auth.user()
  .onCreate(async (user) => {
    const uid = user.uid;
    const docRef = admin.firestore().collection("users").doc(uid);

    await admin.firestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(docRef);
      const existing = snapshot.data() || {};

      transaction.set(
        docRef,
        {
          uid,
          email: user.email || existing.email || null,
          displayName: user.displayName || existing.displayName || null,
          photoURL: user.photoURL || existing.photoURL || null,
          accountStatus: existing.accountStatus || "active",
          role: existing.role || "user",
          subscriptionPlan: existing.subscriptionPlan || "free",
          subscriptionStatus: existing.subscriptionStatus || "inactive",
          phoneVerified: existing.phoneVerified === true,
          proVerified: existing.proVerified === true,
          createdAt:
            existing.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
  });
