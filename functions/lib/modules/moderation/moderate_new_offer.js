"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.moderateNewOffer = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const nodemailer = __importStar(require("nodemailer"));
const env_1 = require("../../config/env");
// ── Helpers ───────────────────────────────────────────────────────────────────
function nowTs() {
    return admin.firestore.FieldValue.serverTimestamp();
}
const FORBIDDEN_WORDS = [
    "enculé", "pute", "nazi", "hitler", "viol", "tuer", "bombe",
];
function runModeration(text) {
    const lowered = String(text || "").toLowerCase();
    const hit = FORBIDDEN_WORDS.find((w) => lowered.includes(w));
    if (hit) {
        return {
            ok: false,
            provider: "rules-fallback",
            score: 0.99,
            categories: { forbidden_word: hit },
            reasonInternal: `Mot interdit détecté: ${hit}`,
            userMessage: "Votre annonce contient des termes non conformes aux CGU. Merci de reformuler avec un langage neutre et respectueux.",
        };
    }
    return {
        ok: true,
        provider: "rules-fallback",
        score: 0.01,
        categories: {},
    };
}
async function sendFlagEmail(opts) {
    const host = process.env.SMTP_HOST;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;
    const from = process.env.SMTP_FROM;
    if (!host || !user || !pass || !from) {
        console.warn("[moderation] SMTP non configuré, email ignoré");
        return;
    }
    const transporter = nodemailer.createTransport({
        host,
        port: Number(process.env.SMTP_PORT || "587"),
        secure: false,
        auth: { user, pass },
    });
    await transporter.sendMail({ from, to: opts.to, subject: opts.subject, text: opts.text });
}
async function notifyUser(uid, payload) {
    await admin
        .firestore()
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .add({ ...payload, createdAt: nowTs(), read: false });
}
// ── Trigger ───────────────────────────────────────────────────────────────────
exports.moderateNewOffer = (0, firestore_1.onDocumentCreated)({ document: "offers/{offerId}", region: env_1.PROJECT_REGION }, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const offerId = event.params.offerId;
    const offer = snap.data() || {};
    const uid = (offer.uid || offer.userId);
    if (!uid)
        return;
    // Force un état safe dès la création
    await snap.ref.set({
        moderation: {
            status: "PENDING",
            checkedAt: null,
            provider: null,
            score: null,
            categories: {},
            reason: null,
            userMessage: null,
        },
        visibility: { isPublic: false, publishedAt: null },
    }, { merge: true });
    const content = `${offer.title || ""}\n\n${offer.description || ""}\n\n${offer.city || ""}`.trim();
    try {
        const res = runModeration(content);
        if (res.ok) {
            await snap.ref.set({
                moderation: {
                    status: "APPROVED",
                    checkedAt: nowTs(),
                    provider: res.provider,
                    score: res.score,
                    categories: res.categories,
                    reason: null,
                    userMessage: null,
                },
                visibility: { isPublic: true, publishedAt: nowTs() },
            }, { merge: true });
            // Notifications favoris
            try {
                const category = offer.category || null;
                const subCategory = offer.subCategory || null;
                const title = offer.title || "";
                if (category) {
                    const usersQuery = await admin
                        .firestore()
                        .collection("users")
                        .where("favoriteCategories", "array-contains", category)
                        .get();
                    const batch = admin.firestore().batch();
                    const now = admin.firestore.Timestamp.now();
                    for (const userDoc of usersQuery.docs) {
                        if (userDoc.id === uid)
                            continue;
                        const userData = userDoc.data() || {};
                        const selectedCats = Array.isArray(userData.selectedFavoriteCategories)
                            ? userData.selectedFavoriteCategories.map(String)
                            : [];
                        const selectedSubcats = Array.isArray(userData.selectedFavoriteSubcategories)
                            ? userData.selectedFavoriteSubcategories.map(String)
                            : [];
                        let shouldNotify = selectedCats.includes(String(category));
                        if (subCategory) {
                            shouldNotify =
                                shouldNotify && (selectedSubcats.length === 0 || selectedSubcats.includes(String(subCategory)));
                        }
                        if (!shouldNotify)
                            continue;
                        const notifRef = admin.firestore().collection("notifications").doc();
                        batch.set(notifRef, {
                            userId: userDoc.id,
                            offerId,
                            title: `Nouvelle offre : ${category}`,
                            message: title,
                            category,
                            subCategory,
                            read: false,
                            createdAt: now,
                        });
                    }
                    await batch.commit();
                }
            }
            catch (e) {
                const msg = e instanceof Error ? e.message : String(e);
                console.warn("[moderation] Notifications favoris échouées", { offerId, uid, message: msg });
            }
            return;
        }
        // REJECT
        await snap.ref.set({
            moderation: {
                status: "REJECTED",
                checkedAt: nowTs(),
                provider: res.provider,
                score: res.score,
                categories: res.categories,
                reason: res.reasonInternal || "Non conforme",
                userMessage: res.userMessage ||
                    "Votre annonce n'est pas conforme aux CGU. Merci de reformuler et de renvoyer.",
            },
            visibility: { isPublic: false, publishedAt: null },
        }, { merge: true });
        await notifyUser(uid, {
            type: "OFFER_REJECTED",
            offerId,
            title: "Annonce à reformuler",
            message: res.userMessage ||
                "Votre annonce n'est pas conforme aux CGU. Merci de reformuler et de renvoyer.",
        });
        const to = process.env.FLAGGED_OFFERS_MAILBOX || "annonces-signalees@tondomaine.com";
        try {
            await sendFlagEmail({
                to,
                subject: `Annonce rejetée (${offerId}) - ${offer.title || "Sans titre"}`,
                text: [
                    "Annonce rejetée",
                    "",
                    `offerId: ${offerId}`,
                    `uid: ${uid}`,
                    "",
                    `Titre: ${offer.title || ""}`,
                    `Ville: ${offer.city || ""}`,
                    `Prix: ${offer.price || ""}`,
                    "",
                    `Raison: ${res.reasonInternal || "Non conforme"}`,
                    `Catégories: ${JSON.stringify(res.categories || {}, null, 2)}`,
                    "",
                    `Contenu:\n${content}`,
                ].join("\n"),
            });
        }
        catch (emailErr) {
            const msg = emailErr instanceof Error ? emailErr.message : String(emailErr);
            console.warn("[moderation] Email flagged offers échoué", { offerId, uid, message: msg });
        }
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        await snap.ref.set({
            moderation: {
                status: "ERROR",
                checkedAt: nowTs(),
                provider: "unknown",
                reason: msg || "Erreur moderation",
                userMessage: "Votre annonce est en cours de vérification. Un délai supplémentaire est nécessaire. Réessayez plus tard.",
            },
            visibility: { isPublic: false, publishedAt: null },
        }, { merge: true });
    }
});
//# sourceMappingURL=moderate_new_offer.js.map