import admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import { trackProductEventBackend } from "../services/analytics";
import { toHttpsError } from "../services/errors";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

export const toggleFavorite = onCall({ region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
  const userId = requireAuthUid(request);
  const listingId = normalizeString(request.data?.listingId);
  if (!listingId) {
    throw new HttpsError("invalid-argument", "listingId is required");
  }

  try {
    const listingRef = db.collection(COLLECTIONS.listings).doc(listingId);
    const favoriteId = `${userId}__${listingId}`;
    const favoriteRef = db.collection(COLLECTIONS.favorites).doc(favoriteId);
    const legacyFavoriteRef = db.collection(COLLECTIONS.users).doc(userId).collection("favoriteOffers").doc(listingId);
    const userRef = db.collection(COLLECTIONS.users).doc(userId);

    let active = false;
    await db.runTransaction(async (transaction) => {
      const [listingSnap, favoriteSnap] = await Promise.all([
        transaction.get(listingRef),
        transaction.get(favoriteRef),
      ]);

      if (!listingSnap.exists) {
        throw new HttpsError("not-found", "Listing not found");
      }

      const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
      if (normalizeString(listingData.status) !== "active" || normalizeString(listingData.visibility) !== "public") {
        throw new HttpsError("failed-precondition", "Only public active listings can be favorited");
      }

      if (favoriteSnap.exists) {
        active = false;
        transaction.delete(favoriteRef);
        transaction.delete(legacyFavoriteRef);
        transaction.set(listingRef, {
          favoriteCount: admin.firestore.FieldValue.increment(-1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      } else {
        active = true;
        transaction.set(favoriteRef, {
          id: favoriteId,
          userId,
          listingId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(legacyFavoriteRef, {
          listingId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(listingRef, {
          favoriteCount: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      transaction.set(userRef, {
        favoriteOffersUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    await trackProductEventBackend({
      eventName: active ? "listing_favorite_added" : "listing_favorite_removed",
      userId,
      listingId,
    });

    logger.info("marketplace_favorite_toggled", {
      listingId,
      userId,
      active,
    });

    return {
      ok: true,
      active,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to toggle favorite");
  }
});