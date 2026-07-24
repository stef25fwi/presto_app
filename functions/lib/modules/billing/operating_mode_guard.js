"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isCommercialBillingEnabled = isCommercialBillingEnabled;
exports.hasCurrentCommercialLegalAcceptance = hasCurrentCommercialLegalAcceptance;
exports.assertCommercialBillingEnabled = assertCommercialBillingEnabled;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("../../core/firestore");
function asRecord(value) {
    return value && typeof value === "object" && !Array.isArray(value)
        ? value
        : {};
}
function normalized(value) {
    return String(value ?? "").trim();
}
function isCommercialBillingEnabled(data) {
    if (!data)
        return false;
    return normalized(data.operatingMode).toLowerCase() === "commercial"
        && data.subscriptionSectionEnabled === true
        && data.stripeEnabled === true
        && data.freeAccessMode === false;
}
function hasCurrentCommercialLegalAcceptance(userData, legalData) {
    if (!userData || !legalData)
        return false;
    if (normalized(legalData.operatingMode).toLowerCase() !== "commercial") {
        return false;
    }
    const acceptance = asRecord(userData.legalAcceptance);
    return normalized(acceptance.operatingMode) === "commercial"
        && normalized(acceptance.legalVersion) === normalized(legalData.legalVersion)
        && normalized(acceptance.cguVersion) === normalized(legalData.cguVersion)
        && normalized(acceptance.privacyVersion) === normalized(legalData.privacyVersion)
        && normalized(legalData.legalVersion).length > 0
        && normalized(legalData.cguVersion).length > 0
        && normalized(legalData.privacyVersion).length > 0;
}
async function assertCommercialBillingEnabled(userId) {
    const uid = userId.trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Connexion requise pour s’abonner");
    }
    const [subscriptionSnapshot, legalSnapshot, userSnapshot] = await Promise.all([
        firestore_1.db.collection("app_config").doc("subscriptions").get(),
        firestore_1.db.collection("app_config").doc("legal").get(),
        firestore_1.db.collection("users").doc(uid).get(),
    ]);
    if (!isCommercialBillingEnabled(subscriptionSnapshot.data())) {
        throw new https_1.HttpsError("failed-precondition", "Ilipresto est actuellement en bêta gratuite. Aucun abonnement ou paiement n’est actif.");
    }
    if (!hasCurrentCommercialLegalAcceptance(userSnapshot.data(), legalSnapshot.data())) {
        throw new https_1.HttpsError("failed-precondition", "Acceptez les conditions commerciales et la politique de confidentialité actives avant de souscrire.");
    }
}
//# sourceMappingURL=operating_mode_guard.js.map