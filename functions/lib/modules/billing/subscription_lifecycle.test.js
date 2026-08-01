"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const stripe_webhook_1 = require("./stripe_webhook");
// Les identifiants de prix viennent des secrets, absents en test : on passe
// donc par les métadonnées, qui font foi côté Stripe comme côté application.
function subscriptionWithPlan(plan, status) {
    return { id: "sub_1", status, metadata: { plan } };
}
(0, node_test_1.default)("un abonnement en essai ouvre les mêmes droits qu'un abonnement actif", () => {
    strict_1.default.equal((0, stripe_webhook_1.appStatus)("active"), "active");
    strict_1.default.equal((0, stripe_webhook_1.appStatus)("trialing"), "active");
});
(0, node_test_1.default)("un impayé suspend sans annuler", () => {
    for (const status of ["past_due", "unpaid", "incomplete", "paused"]) {
        strict_1.default.equal((0, stripe_webhook_1.appStatus)(status), "pastDue", status);
    }
});
(0, node_test_1.default)("une résiliation est distinguée d'une suspension", () => {
    strict_1.default.equal((0, stripe_webhook_1.appStatus)("canceled"), "canceled");
    strict_1.default.equal((0, stripe_webhook_1.appStatus)("cancelled"), "canceled");
});
(0, node_test_1.default)("un statut Stripe inconnu ne donne aucun droit", () => {
    // Défaut fermé : un nouveau statut Stripe ne doit jamais ouvrir l'accès.
    strict_1.default.equal((0, stripe_webhook_1.appStatus)("incomplete_expired"), "inactive");
    strict_1.default.equal((0, stripe_webhook_1.appStatus)(""), "inactive");
    strict_1.default.equal((0, stripe_webhook_1.appStatus)("something_new"), "inactive");
});
(0, node_test_1.default)("la casse du statut Stripe est sans effet", () => {
    strict_1.default.equal((0, stripe_webhook_1.appStatus)("ACTIVE"), "active");
    strict_1.default.equal((0, stripe_webhook_1.appStatus)("Past_Due"), "pastDue");
});
(0, node_test_1.default)("le cycle de vie complet d'un abonnement se traduit correctement", () => {
    const journey = [
        ["incomplete", "pastDue"],
        ["trialing", "active"],
        ["active", "active"],
        ["past_due", "pastDue"],
        ["active", "active"],
        ["canceled", "canceled"],
    ];
    for (const [stripeStatus, expected] of journey) {
        strict_1.default.equal((0, stripe_webhook_1.appStatus)(stripeStatus), expected, stripeStatus);
    }
});
(0, node_test_1.default)("le plan est reconnu depuis les métadonnées Stripe", () => {
    strict_1.default.equal((0, stripe_webhook_1.planFromStripe)(subscriptionWithPlan("ilipro", "active")), "ilipro");
    strict_1.default.equal((0, stripe_webhook_1.planFromStripe)(subscriptionWithPlan("ilipresto_plus", "active")), "ilipresto_plus");
    strict_1.default.equal((0, stripe_webhook_1.planFromStripe)(subscriptionWithPlan("ilipresto+", "active")), "ilipresto_plus");
    strict_1.default.equal((0, stripe_webhook_1.planFromStripe)(subscriptionWithPlan("iliprestoplus", "active")), "ilipresto_plus");
});
(0, node_test_1.default)("un plan inconnu n'est pas deviné", () => {
    // syncSubscription refuse alors d'activer l'abonnement : mieux vaut une
    // erreur visible qu'un plan arbitraire ouvrant des droits non payés.
    strict_1.default.equal((0, stripe_webhook_1.planFromStripe)(subscriptionWithPlan("offre_maison", "active")), null);
    strict_1.default.equal((0, stripe_webhook_1.planFromStripe)({ id: "sub_1", status: "active" }), null);
});
(0, node_test_1.default)("les noms de plan applicatifs sont stables", () => {
    strict_1.default.equal((0, stripe_webhook_1.appPlan)("ilipresto_plus"), "iliprestoPlus");
    strict_1.default.equal((0, stripe_webhook_1.appPlan)("ilipro"), "ilipro");
});
(0, node_test_1.default)("un webhook tardif ne réhydrate pas un compte supprimé", () => {
    strict_1.default.equal((0, stripe_webhook_1.isDeletedAccountStatus)("deletion_processing"), true);
    strict_1.default.equal((0, stripe_webhook_1.isDeletedAccountStatus)("deleted"), true);
    strict_1.default.equal((0, stripe_webhook_1.isDeletedAccountStatus)("DELETED"), true);
    strict_1.default.equal((0, stripe_webhook_1.isDeletedAccountStatus)("active"), false);
});
(0, node_test_1.default)("un renouvellement rejoué hors séquence ne rétrograde pas l'abonnement", () => {
    const lastProcessed = 1_700_000_100_000;
    strict_1.default.equal((0, stripe_webhook_1.shouldApplyStripeEvent)(lastProcessed, 1_700_000_050_000), false);
    strict_1.default.equal((0, stripe_webhook_1.shouldApplyStripeEvent)(lastProcessed, 1_700_000_200_000), true);
});
//# sourceMappingURL=subscription_lifecycle.test.js.map