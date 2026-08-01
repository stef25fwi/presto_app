"use strict";
/**
 * Cloisonnement entre le Stripe de test et le Stripe réel.
 *
 * Deux confusions coûtent cher et ne se voient pas au déploiement :
 *
 * 1. une clé `sk_live_` configurée sur un projet Firebase qui n'est pas la
 *    production — les paiements réels atterrissent alors dans une base d'essai ;
 * 2. un webhook de test reçu par l'endpoint de production (ou l'inverse) :
 *    Stripe signe les deux avec des secrets distincts, mais un secret recopié
 *    d'un environnement à l'autre rend la signature valide et injecte des
 *    abonnements fantômes.
 *
 * Ce module ne contient que des fonctions pures, testables sans Stripe ni
 * Firestore.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.LIVE_STRIPE_PROJECT_IDS = void 0;
exports.stripeModeFromSecret = stripeModeFromSecret;
exports.isStripeModeAllowedForProject = isStripeModeAllowedForProject;
exports.livemodeVerdict = livemodeVerdict;
exports.describeModeMismatch = describeModeMismatch;
/** Projets Firebase autorisés à porter une clé Stripe réelle. */
exports.LIVE_STRIPE_PROJECT_IDS = new Set(["presto-app-74abe"]);
function stripeModeFromSecret(secret) {
    const value = String(secret ?? "").trim();
    if (value.startsWith("sk_live_") || value.startsWith("rk_live_"))
        return "live";
    if (value.startsWith("sk_test_") || value.startsWith("rk_test_"))
        return "test";
    return null;
}
/**
 * Une clé réelle n'est acceptée que sur un projet de production. L'inverse
 * reste permis : une clé de test sur la production sert aux répétitions avant
 * bascule commerciale.
 */
function isStripeModeAllowedForProject(mode, projectId) {
    if (mode === "test")
        return true;
    return exports.LIVE_STRIPE_PROJECT_IDS.has(String(projectId ?? "").trim());
}
/**
 * Compare le drapeau `livemode` de l'événement au mode de la clé configurée.
 *
 * `unknown` couvre les charges utiles sans `livemode` explicite : on ne peut
 * rien conclure, et refuser serait pire que traiter.
 */
function livemodeVerdict(eventLivemode, keyMode) {
    if (typeof eventLivemode !== "boolean")
        return "unknown";
    const eventMode = eventLivemode ? "live" : "test";
    return eventMode === keyMode ? "match" : "mismatch";
}
function describeModeMismatch(eventLivemode, keyMode) {
    const eventMode = eventLivemode === true ? "live" : "test";
    return `Événement Stripe en mode ${eventMode} reçu avec une clé ${keyMode}`;
}
//# sourceMappingURL=stripe_mode.js.map