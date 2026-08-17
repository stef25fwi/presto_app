import { FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK } from "../../config/env";
import { db } from "../../core/firestore";
import { buildPublicProfessionalProfileProjection } from "./public_profile_core";

const PRIVATE_COLLECTION = "pro_profiles";
const PUBLIC_COLLECTION = "public_pro_profiles";

export const setPublicProfessionalProfileVisibility = onCall(
  {
    enforceAppCheck: ENFORCE_APP_CHECK,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Vous devez être connecté pour modifier la visibilité de votre profil professionnel.",
      );
    }

    if (typeof request.data?.enabled !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "Le paramètre enabled doit être un booléen.",
      );
    }

    const uid = request.auth.uid;
    const enabled = request.data.enabled as boolean;
    const privateRef = db.collection(PRIVATE_COLLECTION).doc(uid);
    const snapshot = await privateRef.get();

    if (!snapshot.exists) {
      if (!enabled) return { ok: true, enabled: false };
      throw new HttpsError(
        "failed-precondition",
        "Votre profil professionnel doit être vérifié avant de pouvoir être rendu public.",
      );
    }

    if (enabled) {
      const candidate = {
        ...(snapshot.data() ?? {}),
        publicProfileEnabled: true,
      };
      if (!buildPublicProfessionalProfileProjection(candidate)) {
        throw new HttpsError(
          "failed-precondition",
          "Votre profil professionnel vérifié ne contient pas encore les informations minimales requises.",
        );
      }
    }

    await privateRef.set(
      {
        publicProfileEnabled: enabled,
        publicProfileConsentUpdatedAt: FieldValue.serverTimestamp(),
        publicProfileConsentSource: "authenticated_user_callable",
      },
      { merge: true },
    );

    return { ok: true, enabled };
  },
);

export const syncPublicProfessionalProfile = onDocumentWritten(
  `${PRIVATE_COLLECTION}/{uid}`,
  async (event) => {
    const uid = String(event.params.uid ?? "").trim();
    if (!uid) return;

    const publicRef = db.collection(PUBLIC_COLLECTION).doc(uid);
    const after = event.data?.after;

    if (!after?.exists) {
      await publicRef.delete();
      return;
    }

    const projection = buildPublicProfessionalProfileProjection(
      (after.data() ?? {}) as Record<string, unknown>,
    );

    if (!projection) {
      await publicRef.delete();
      return;
    }

    await publicRef.set({
      ...projection,
      updatedAt: FieldValue.serverTimestamp(),
    });
  },
);
