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
exports.onAuthUserCreated = void 0;
const functionsV1 = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const env_1 = require("../../config/env");
/**
 * Auth trigger v1 — garantit un document `users/{uid}` canonique dès qu'un
 * compte Firebase Auth est provisionné.
 *
 * Le trigger utilise une transaction et `merge` pour couvrir la course où le
 * client écrit ses champs de profil avant la fin du trigger Auth. Les champs
 * d'autorité (rôle, abonnement, vérifications et createdAt) restent toujours
 * définis par l'Admin SDK.
 */
exports.onAuthUserCreated = functionsV1
    .region(env_1.PROJECT_REGION)
    .auth.user()
    .onCreate(async (user) => {
    const uid = user.uid;
    const docRef = admin.firestore().collection("users").doc(uid);
    await admin.firestore().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(docRef);
        const existing = snapshot.data() || {};
        transaction.set(docRef, {
            uid,
            email: user.email || existing.email || null,
            displayName: user.displayName || existing.displayName || null,
            photoURL: user.photoURL || existing.photoURL || null,
            accountStatus: existing.accountStatus || "active",
            role: existing.role || "user",
            subscriptionPlan: existing.subscriptionPlan || "free",
            subscriptionStatus: existing.subscriptionStatus || "inactive",
            phoneVerified: existing.phoneVerified === true,
            proVerified: existing.proVerified === true,
            createdAt: existing.createdAt || admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
});
//# sourceMappingURL=on_auth_user_created.js.map