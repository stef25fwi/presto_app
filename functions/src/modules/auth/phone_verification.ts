import admin from "../../core/firebase_admin_compat";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { COLLECTIONS } from "../../shared/constants";

const FREE_PHONE_VERIFICATION_ATTEMPTS_PER_DAY = 1;
const PHONE_VERIFICATION_WINDOW_MS = 24 * 60 * 60 * 1000;
const E164_PHONE_PATTERN = /^\+[0-9]{10,15}$/;
const RESERVATION_ID_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;

type SubscriptionPlan = "free" | "ilipresto_plus" | "ilipro";
type PhoneVerificationAttemptAction = "reserve" | "commit" | "release";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function normalizeSubscriptionPlan(value: unknown): SubscriptionPlan {
  const raw = String(value ?? "").trim().toLowerCase().replace(/[\s-]/g, "_");
  if (raw === "ilipresto_plus" || raw === "iliprestoplus" || raw === "ilipresto+") {
    return "ilipresto_plus";
  }
  if (raw === "ilipro") return "ilipro";
  return "free";
}

function hasPrivilegedPhoneQuotaBypass(token: Record<string, unknown>): boolean {
  if (token.admin === true || token.superadmin === true || token.isAdmin === true) {
    return true;
  }
  const roles = Array.isArray(token.roles)
    ? token.roles.map((role) => String(role).trim().toLowerCase())
    : [];
  return roles.includes("admin") || roles.includes("superadmin");
}

function parseAttemptAction(value: unknown): PhoneVerificationAttemptAction {
  const action = String(value ?? "reserve").trim().toLowerCase();
  if (action === "reserve" || action === "commit" || action === "release") {
    return action;
  }
  throw new HttpsError("invalid-argument", "Action de tentative SMS invalide.");
}

function requireReservationId(value: unknown): string {
  const reservationId = String(value ?? "").trim();
  if (!RESERVATION_ID_PATTERN.test(reservationId)) {
    throw new HttpsError("invalid-argument", "Identifiant de réservation SMS invalide.");
  }
  return reservationId;
}

function sanitizeReleaseReason(value: unknown): string {
  const raw = String(value ?? "firebase_pre_send_failure").trim().slice(0, 64);
  return (raw || "firebase_pre_send_failure").replace(/[^A-Za-z0-9_.-]/g, "_");
}

/**
 * Gère la tentative d'envoi SMS de l'application officielle.
 *
 * - reserve : réserve le quota avant Firebase Phone Auth ;
 * - commit : marque la réservation comme consommée dès que `codeSent` est reçu ;
 * - release : recrédite la réservation si Firebase échoue avant `codeSent`.
 *
 * Les comptes au plan free disposent d'une tentative sur une fenêtre glissante
 * de 24 h. Les plans ilipresto_plus / ilipro et les comptes administrateurs
 * sont exemptés. Les mutations sont transactionnelles afin de rester idempotentes
 * et de ne jamais libérer une réservation différente ou déjà envoyée.
 */
export const reservePhoneVerificationAttempt = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const uid = requireAuthUid(request);
    const action = parseAttemptAction(request.data?.action);
    const userRef = db.collection(COLLECTIONS.users).doc(uid);
    const quotaRef = userRef.collection("rateLimits").doc("phoneVerification");

    if (action === "commit") {
      const reservationId = requireReservationId(request.data?.reservationId);
      const committed = await db.runTransaction(async (transaction) => {
        const quotaSnap = await transaction.get(quotaRef);
        const quotaData = quotaSnap.data() ?? {};
        const currentReservationId = String(quotaData.reservationId ?? "");
        const state = String(quotaData.reservationState ?? "").toLowerCase();

        if (currentReservationId !== reservationId) return false;
        if (state === "sent") return true;
        if (state !== "reserved") return false;

        transaction.set(
          quotaRef,
          {
            reservationState: "sent",
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        return true;
      });

      logger.info("account_phone_verification_attempt_committed", {
        uid,
        committed,
      });
      return { committed };
    }

    if (action === "release") {
      const reservationId = requireReservationId(request.data?.reservationId);
      const releaseReason = sanitizeReleaseReason(request.data?.reason);
      const released = await db.runTransaction(async (transaction) => {
        const quotaSnap = await transaction.get(quotaRef);
        const quotaData = quotaSnap.data() ?? {};
        const currentReservationId = String(quotaData.reservationId ?? "");
        const state = String(quotaData.reservationState ?? "").toLowerCase();

        if (currentReservationId !== reservationId || state !== "reserved") {
          return false;
        }

        transaction.set(
          quotaRef,
          {
            reservationState: "released",
            nextAllowedAt: admin.firestore.FieldValue.delete(),
            releasedAt: admin.firestore.FieldValue.serverTimestamp(),
            releaseReason,
            totalReleased: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        return true;
      });

      logger.info("account_phone_verification_attempt_released", {
        uid,
        released,
        releaseReason,
      });
      return { released };
    }

    const phoneNumber = String(request.data?.phoneNumber ?? "").trim();
    if (!E164_PHONE_PATTERN.test(phoneNumber)) {
      throw new HttpsError(
        "invalid-argument",
        "Le numéro doit être au format international E.164.",
      );
    }

    const userSnap = await userRef.get();
    const userData = userSnap.data() ?? {};
    const plan = normalizeSubscriptionPlan(
      userData.subscriptionPlan ?? userData.plan,
    );
    const token = (request.auth?.token ?? {}) as Record<string, unknown>;
    const privileged = hasPrivilegedPhoneQuotaBypass(token);

    if (plan !== "free" || privileged) {
      return {
        allowed: true,
        limited: false,
        plan,
        dailyLimit: null,
        nextAllowedAt: null,
        reservationId: null,
      };
    }

    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();
    const reservationId = quotaRef.parent.doc().id;

    const reservation = await db.runTransaction(async (transaction) => {
      const quotaSnap = await transaction.get(quotaRef);
      const quotaData = quotaSnap.data() ?? {};
      const lastAttemptAt = quotaData.lastAttemptAt instanceof admin.firestore.Timestamp
        ? quotaData.lastAttemptAt as admin.firestore.Timestamp
        : null;
      const previousState = String(quotaData.reservationState ?? "").toLowerCase();
      const consumesQuota = lastAttemptAt != null && previousState !== "released";

      if (consumesQuota && lastAttemptAt != null) {
        const nextAllowedAtMs = lastAttemptAt.toMillis() + PHONE_VERIFICATION_WINDOW_MS;
        if (nowMs < nextAllowedAtMs) {
          const nextAllowedAt = new Date(nextAllowedAtMs).toISOString();
          throw new HttpsError(
            "resource-exhausted",
            "La tentative SMS quotidienne a déjà été utilisée. Réessayez après le délai indiqué.",
            {
              kind: "phoneVerification",
              plan,
              dailyLimit: FREE_PHONE_VERIFICATION_ATTEMPTS_PER_DAY,
              nextAllowedAt,
            },
          );
        }
      }

      const nextAllowedAtMs = nowMs + PHONE_VERIFICATION_WINDOW_MS;
      const nextAllowedAt = new Date(nextAllowedAtMs).toISOString();
      transaction.set(
        quotaRef,
        {
          lastAttemptAt: now,
          nextAllowedAt: admin.firestore.Timestamp.fromMillis(nextAllowedAtMs),
          dailyLimit: FREE_PHONE_VERIFICATION_ATTEMPTS_PER_DAY,
          rollingWindowHours: 24,
          phoneSuffix: phoneNumber.slice(-4),
          reservationId,
          reservationState: "reserved",
          reservedAt: now,
          releaseReason: admin.firestore.FieldValue.delete(),
          releasedAt: admin.firestore.FieldValue.delete(),
          sentAt: admin.firestore.FieldValue.delete(),
          totalAttempts: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      return { nextAllowedAt };
    });

    logger.info("account_phone_verification_attempt_reserved", {
      uid,
      plan,
      dailyLimit: FREE_PHONE_VERIFICATION_ATTEMPTS_PER_DAY,
    });

    return {
      allowed: true,
      limited: true,
      plan,
      dailyLimit: FREE_PHONE_VERIFICATION_ATTEMPTS_PER_DAY,
      nextAllowedAt: reservation.nextAllowedAt,
      reservationId,
    };
  },
);

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
