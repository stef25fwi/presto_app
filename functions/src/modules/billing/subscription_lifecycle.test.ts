import assert from "node:assert/strict";
import test from "node:test";

import {
  appPlan,
  appStatus,
  isDeletedAccountStatus,
  planFromStripe,
  shouldApplyStripeEvent,
} from "./stripe_webhook";

// Les identifiants de prix viennent des secrets, absents en test : on passe
// donc par les métadonnées, qui font foi côté Stripe comme côté application.
function subscriptionWithPlan(plan: string, status: string) {
  return { id: "sub_1", status, metadata: { plan } };
}

test("un abonnement en essai ouvre les mêmes droits qu'un abonnement actif", () => {
  assert.equal(appStatus("active"), "active");
  assert.equal(appStatus("trialing"), "active");
});

test("un impayé suspend sans annuler", () => {
  for (const status of ["past_due", "unpaid", "incomplete", "paused"]) {
    assert.equal(appStatus(status), "pastDue", status);
  }
});

test("une résiliation est distinguée d'une suspension", () => {
  assert.equal(appStatus("canceled"), "canceled");
  assert.equal(appStatus("cancelled"), "canceled");
});

test("un statut Stripe inconnu ne donne aucun droit", () => {
  // Défaut fermé : un nouveau statut Stripe ne doit jamais ouvrir l'accès.
  assert.equal(appStatus("incomplete_expired"), "inactive");
  assert.equal(appStatus(""), "inactive");
  assert.equal(appStatus("something_new"), "inactive");
});

test("la casse du statut Stripe est sans effet", () => {
  assert.equal(appStatus("ACTIVE"), "active");
  assert.equal(appStatus("Past_Due"), "pastDue");
});

test("le cycle de vie complet d'un abonnement se traduit correctement", () => {
  const journey: Array<[string, string]> = [
    ["incomplete", "pastDue"],
    ["trialing", "active"],
    ["active", "active"],
    ["past_due", "pastDue"],
    ["active", "active"],
    ["canceled", "canceled"],
  ];

  for (const [stripeStatus, expected] of journey) {
    assert.equal(appStatus(stripeStatus), expected, stripeStatus);
  }
});

test("le plan est reconnu depuis les métadonnées Stripe", () => {
  assert.equal(planFromStripe(subscriptionWithPlan("ilipro", "active")), "ilipro");
  assert.equal(
    planFromStripe(subscriptionWithPlan("ilipresto_plus", "active")),
    "ilipresto_plus",
  );
  assert.equal(
    planFromStripe(subscriptionWithPlan("ilipresto+", "active")),
    "ilipresto_plus",
  );
  assert.equal(
    planFromStripe(subscriptionWithPlan("iliprestoplus", "active")),
    "ilipresto_plus",
  );
});

test("un plan inconnu n'est pas deviné", () => {
  // syncSubscription refuse alors d'activer l'abonnement : mieux vaut une
  // erreur visible qu'un plan arbitraire ouvrant des droits non payés.
  assert.equal(planFromStripe(subscriptionWithPlan("offre_maison", "active")), null);
  assert.equal(planFromStripe({ id: "sub_1", status: "active" }), null);
});

test("les noms de plan applicatifs sont stables", () => {
  assert.equal(appPlan("ilipresto_plus"), "iliprestoPlus");
  assert.equal(appPlan("ilipro"), "ilipro");
});

test("un webhook tardif ne réhydrate pas un compte supprimé", () => {
  assert.equal(isDeletedAccountStatus("deletion_processing"), true);
  assert.equal(isDeletedAccountStatus("deleted"), true);
  assert.equal(isDeletedAccountStatus("DELETED"), true);
  assert.equal(isDeletedAccountStatus("active"), false);
});

test("un renouvellement rejoué hors séquence ne rétrograde pas l'abonnement", () => {
  const lastProcessed = 1_700_000_100_000;
  assert.equal(shouldApplyStripeEvent(lastProcessed, 1_700_000_050_000), false);
  assert.equal(shouldApplyStripeEvent(lastProcessed, 1_700_000_200_000), true);
});
