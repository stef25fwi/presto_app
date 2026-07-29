import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { canProceedRateLimited } from "../../../core/rate_limit";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES } from "../../messaging/participants";
import { toHttpsError } from "../services/errors";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

// Firestore Timestamp instances aren't JSON-serializable as-is; convert them
// (and nested values) to ISO strings so the callable response is plain JSON.
export function serializeFirestoreValue(value: unknown): unknown {
  if (value === null || value === undefined) {
    return value;
  }
  if (typeof value === "object" && "toDate" in (value as Record<string, unknown>) &&
    typeof (value as { toDate?: unknown }).toDate === "function") {
    return (value as { toDate: () => Date }).toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return value.map(serializeFirestoreValue);
  }
  if (typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
      result[key] = serializeFirestoreValue(entry);
    }
    return result;
  }
  return value;
}

function serializeDoc(
  doc: FirebaseFirestore.DocumentSnapshot | FirebaseFirestore.QueryDocumentSnapshot,
): Record<string, unknown> {
  return {
    id: doc.id,
    ...(serializeFirestoreValue(doc.data() ?? {}) as Record<string, unknown>),
  };
}

const EXPORT_QUERY_LIMIT = 500;

export const exportMyData = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const uid = requireAuthUid(request);

    const rateAllowed = await canProceedRateLimited("account_data_export", uid, 3, 24 * 60 * 60 * 1000);
    if (!rateAllowed) {
      throw new HttpsError("resource-exhausted", "Too many export requests today");
    }

    try {
      const [userSnap, proProfileSnap, proSnap, listingsSnap, reviewsSnap, ...conversationSnaps] =
        await Promise.all([
          db.collection(COLLECTIONS.users).doc(uid).get(),
          db.collection("pro_profiles").doc(uid).get(),
          db.collection(COLLECTIONS.pros).doc(uid).get(),
          db.collection(COLLECTIONS.listings).where("ownerId", "==", uid).limit(EXPORT_QUERY_LIMIT).get(),
          db.collection(COLLECTIONS.reviews).where("reviewerId", "==", uid).limit(EXPORT_QUERY_LIMIT).get(),
          ...CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES.map((field) =>
            db.collection(COLLECTIONS.conversations)
              .where(field, "array-contains", uid)
              .limit(EXPORT_QUERY_LIMIT)
              .get()),
        ]);

      const conversationsById = new Map<string, Record<string, unknown>>();
      for (const snap of conversationSnaps) {
        for (const doc of snap.docs) {
          conversationsById.set(doc.id, serializeDoc(doc));
        }
      }

      const exportedAt = new Date().toISOString();

      logger.info("account_data_export_completed", {
        uid,
        listingCount: listingsSnap.size,
        reviewCount: reviewsSnap.size,
        conversationCount: conversationsById.size,
      });

      return {
        ok: true,
        exportedAt,
        profile: userSnap.exists ? serializeDoc(userSnap) : null,
        proProfile: proProfileSnap.exists ? serializeDoc(proProfileSnap) : null,
        pro: proSnap.exists ? serializeDoc(proSnap) : null,
        listings: listingsSnap.docs.map(serializeDoc),
        reviews: reviewsSnap.docs.map(serializeDoc),
        conversations: Array.from(conversationsById.values()),
        note:
          "Cet export contient votre profil, vos annonces, vos avis et les métadonnées de vos " +
          "conversations (sans le contenu des messages). Pour le contenu détaillé d'une " +
          "conversation, contactez le support.",
      };
    } catch (error) {
      throw toHttpsError(error, "Unable to export account data");
    }
  },
);
