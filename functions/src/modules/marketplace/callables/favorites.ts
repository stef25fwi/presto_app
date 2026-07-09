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

function normalizeSubscriptionPlan(value: unknown): "free" | "ilipresto_plus" | "ilipro" {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "ilipresto_plus" || normalized === "iliprestoplus" || normalized === "ilipresto+") {
    return "ilipresto_plus";
  }
  if (normalized === "ilipro") {
    return "ilipro";
  }
  return "free";
}

const FREE_PLAN_MAX_FAVORITES = 5;

async function readSubscriptionConfigFreeAccessMode(): Promise<boolean> {
  const [snakeCaseSnap, camelCaseSnap] = await Promise.all([
    db.collection("app_config").doc("subscriptions").get().catch(() => null),
    db.collection(COLLECTIONS.appConfig).doc("subscriptions").get().catch(() => null),
  ]);

  const data = snakeCaseSnap?.data() ?? camelCaseSnap?.data() ?? {};
  return data.freeAccessMode !== false;
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
    const userRef = db.collection(COLLECTIONS.users).doc(userId);
    const userFavoriteRef = userRef.collection("favorites").doc(listingId);

    const freeAccessMode = await readSubscriptionConfigFreeAccessMode();

    let active = false;
    await db.runTransaction(async (transaction) => {
      const [listingSnap, favoriteSnap, userFavoriteSnap, userSnap] = await Promise.all([
        transaction.get(listingRef),
        transaction.get(favoriteRef),
        transaction.get(userFavoriteRef),
        transaction.get(userRef),
      ]);

      const alreadyFavorite = favoriteSnap.exists || userFavoriteSnap.exists;

      if (alreadyFavorite) {
        active = false;
        transaction.delete(favoriteRef);
        transaction.delete(userFavoriteRef);

        if (listingSnap.exists) {
          transaction.set(listingRef, {
            favoriteCount: admin.firestore.FieldValue.increment(-1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }

        transaction.set(userRef, {
          favoriteOffersUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          activeFavoritesCount: admin.firestore.FieldValue.increment(-1),
        }, { merge: true });
        return;
      }

      if (!listingSnap.exists) {
        throw new HttpsError("not-found", "Listing not found");
      }

      const listingData = (listingSnap.data() ?? {}) as Record<string, unknown>;
      if (normalizeString(listingData.status) !== "active" || normalizeString(listingData.visibility) !== "public") {
        throw new HttpsError("failed-precondition", "Only public active listings can be favorited");
      }

      if (!freeAccessMode) {
        const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
        const plan = normalizeSubscriptionPlan(userData.subscriptionPlan);
        const currentFavoritesCount = Number(userData.activeFavoritesCount || 0);
        if (plan === "free" && currentFavoritesCount >= FREE_PLAN_MAX_FAVORITES) {
          throw new HttpsError(
            "resource-exhausted",
            "free plan is limited to 5 favorites",
            { reason: "free_plan_favorites_limit_reached" },
          );
        }
      }

      active = true;
      transaction.set(favoriteRef, {
        id: favoriteId,
        userId,
        listingId,
        offerId: listingId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.set(userFavoriteRef, {
        offerId: listingId,
        listingId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      transaction.set(listingRef, {
        favoriteCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      transaction.set(userRef, {
        favoriteOffersUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        activeFavoritesCount: admin.firestore.FieldValue.increment(1),
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