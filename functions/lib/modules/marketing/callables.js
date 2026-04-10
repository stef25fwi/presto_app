"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendReferralInviteEmail = void 0;
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
function normalizeEmail(value) {
    return String(value || "").trim().toLowerCase();
}
function extractFirstName(value) {
    return String(value || "").trim().split(" ")[0] || "";
}
exports.sendReferralInviteEmail = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const auth = request.auth;
    if (!auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    const recipientEmail = normalizeEmail(request.data?.recipientEmail);
    if (!recipientEmail || !recipientEmail.includes("@")) {
        throw new https_1.HttpsError("invalid-argument", "recipientEmail is required");
    }
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(auth.uid).get();
    const userData = userSnap.data() ?? {};
    const inviterName = String(userData.displayName || userData.display_name || auth.token.name || "Utilisateur e-livre resto").trim();
    const recipientFirstName = extractFirstName(request.data?.recipientFirstName);
    const rewardDescription = String(request.data?.rewardDescription || "Un acces simplifie a e-livre resto").trim();
    const referralUrl = String(request.data?.referralUrl || `${env_1.APP_BASE_URL}/invite?ref=${encodeURIComponent(auth.uid)}`).trim();
    const now = Date.now();
    const eventId = `evt_growth_referral_invite_${auth.uid}_${(0, hash_1.sha256)(recipientEmail).slice(0, 12)}_${Math.floor(now / (24 * 60 * 60 * 1000))}`;
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "growth.referral_invite",
        source_collection: constants_1.COLLECTIONS.users,
        source_id: auth.uid,
        actor_user_id: auth.uid,
        dedupe_key: (0, hash_1.sha256)(`growth.referral_invite:${auth.uid}:${recipientEmail}:${Math.floor(now / (24 * 60 * 60 * 1000))}`),
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
//# sourceMappingURL=callables.js.map