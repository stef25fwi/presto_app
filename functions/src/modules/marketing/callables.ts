import { HttpsError, onCall } from "firebase-functions/v2/https";
import { APP_BASE_URL, PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

function normalizeEmail(value: unknown): string {
  return String(value || "").trim().toLowerCase();
}

function extractFirstName(value: unknown): string {
  return String(value || "").trim().split(" ")[0] || "";
}

export const sendReferralInviteEmail = onCall({ region: PROJECT_REGION }, async (request) => {
  const auth = request.auth;
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "authentication required");
  }

  const recipientEmail = normalizeEmail(request.data?.recipientEmail);
  if (!recipientEmail || !recipientEmail.includes("@")) {
    throw new HttpsError("invalid-argument", "recipientEmail is required");
  }

  const userSnap = await db.collection(COLLECTIONS.users).doc(auth.uid).get();
  const userData = userSnap.data() ?? {};
  const inviterName = String(userData.displayName || userData.display_name || auth.token.name || "Utilisateur e-livre resto").trim();
  const recipientFirstName = extractFirstName(request.data?.recipientFirstName);
  const rewardDescription = String(request.data?.rewardDescription || "Un acces simplifie a e-livre resto").trim();
  const referralUrl = String(request.data?.referralUrl || `${APP_BASE_URL}/invite?ref=${encodeURIComponent(auth.uid)}`).trim();
  const now = Date.now();
  const eventId = `evt_growth_referral_invite_${auth.uid}_${sha256(recipientEmail).slice(0, 12)}_${Math.floor(now / (24 * 60 * 60 * 1000))}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: "growth.referral_invite",
    source_collection: COLLECTIONS.users,
    source_id: auth.uid,
    actor_user_id: auth.uid,
    dedupe_key: sha256(`growth.referral_invite:${auth.uid}:${recipientEmail}:${Math.floor(now / (24 * 60 * 60 * 1000))}`),
    occurred_at: now,
    payload: {
      recipient_email: recipientEmail,
      firstName: recipientFirstName,
      inviterName,
      referralUrl,
      rewardDescription,
    },
    status: "created",
  }, { merge: true });

  return {
    ok: true,
    eventId,
  };
});