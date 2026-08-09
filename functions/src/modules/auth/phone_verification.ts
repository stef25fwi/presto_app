import admin from "../../core/firebase_admin_compat";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import { COLLECTIONS } from "../../shared/constants";

const FREE_PHONE_VERIFICATION_ATTEMPTS_PER_DAY = 1;
const PHONE_VERIFICATION_WINDOW_MS = 24 * 60 * 60 * 1000;
const E164_PHONE_PATTERN = /^\+[0-9]{10,15}$/;

type SubscriptionPlan = "free" | "ilipresto_plus" | "ilipro";

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

/**
 * Réserve une tentative d'envoi SMS avant l'appel Firebase Phone Auth.
 *
 * Les comptes au plan free disposent d'une tentative sur une fenêtre glissante
 * de 24 h. Les plans ilipresto_plus / ilipro et les comptes administrateurs
 * sont exemptés. Le contrôle est transactionnel afin que deux clics concurrents
 * ne puissent pas réserver deux tentatives dans l'application officielle.
 */
export const reservePhoneVerificationAttempt = onCall(
  { region: PROJECT_REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const uid = requireAuthUid(request);
    const phoneNumber = String(request.data?.phoneNumber ?? "").trim();
    if (!E164_PHONE_PATTERN.test(phoneNumber)) {
      throw new HttpsError(
        "invalid-argument",
        "Le numéro doit être au format international E.164.",
      );
    }

    const userRef = db.collection(COLLECTIONS.users).doc(uid);
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
      };
    }

    const quotaRef = userRef.collection("rateLimits").doc("phoneVerification");
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();

    const reservation = await db.runTransaction(async (transaction) => {
      const quotaSnap = await transaction.get(quotaRef);
      const quotaData = quotaSnap.data() ?? {};
      const lastAttemptAt = quotaData.lastAttemptAt instanceof admin.firestore.Timestamp
        ? quotaData.lastAttemptAt as admin.firestore.Timestamp
        : null;

      if (lastAttemptAt != null) {
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
