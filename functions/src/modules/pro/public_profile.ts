import { FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK } from "../../config/env";
import { db } from "../../core/firestore";
import {
  PUBLIC_PROFILE_CONSENT_VERSION,
  buildPublicProfessionalProfileProjection,
  canPublishPublicProfessionalProfile,
} from "./public_profile_core";

const PRIVATE_COLLECTION = "pro_profiles";
const PUBLIC_COLLECTION = "public_pro_profiles";
const CONSENT_COLLECTION = "public_profile_consents";

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
    const consentRef = db.collection(CONSENT_COLLECTION).doc(uid);
    const publicRef = db.collection(PUBLIC_COLLECTION).doc(uid);
    const snapshot = await privateRef.get();

    if (!snapshot.exists) {
      if (enabled) {
        throw new HttpsError(
          "failed-precondition",
          "Votre profil professionnel doit être vérifié avant de pouvoir être rendu public.",
        );
      }

      await Promise.all([
        consentRef.set({
          enabled: false,
          version: PUBLIC_PROFILE_CONSENT_VERSION,
          source: "authenticated_user_callable",
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true }),
        publicRef.delete(),
      ]);
      return { ok: true, enabled: false };
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

    const batch = db.batch();
    batch.set(privateRef, {
      publicProfileEnabled: enabled,
      publicProfileConsentUpdatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    batch.set(consentRef, {
      enabled,
      version: PUBLIC_PROFILE_CONSENT_VERSION,
      source: "authenticated_user_callable",
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    await batch.commit();

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

    const profile = (after.data() ?? {}) as Record<string, unknown>;
    const consentSnapshot = await db.collection(CONSENT_COLLECTION).doc(uid).get();
    const consent = consentSnapshot.exists
      ? (consentSnapshot.data() ?? {}) as Record<string, unknown>
      : undefined;

    if (!canPublishPublicProfessionalProfile(profile, consent)) {
      await publicRef.delete();
      return;
    }

    const projection = buildPublicProfessionalProfileProjection(profile);
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
