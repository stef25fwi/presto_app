import assert from "node:assert/strict";
import test from "node:test";

import {
  UNLIMITED_SUBSCRIPTION_CREDIT,
  isSubscriptionCreditActiveListing,
  normalizeSubscriptionCreditPlan,
  subscriptionCreditLimitsForPlan,
  subscriptionCreditPeriod,
} from "./subscription_credits";

test("normalise les plans utilisés par les crédits", () => {
  assert.equal(normalizeSubscriptionCreditPlan("free"), "free");
  assert.equal(normalizeSubscriptionCreditPlan("ilipresto+"), "ilipresto_plus");
  assert.equal(normalizeSubscriptionCreditPlan("ilipresto-plus"), "ilipresto_plus");
  assert.equal(normalizeSubscriptionCreditPlan("ilipro"), "ilipro");
  assert.equal(normalizeSubscriptionCreditPlan("inconnu"), "free");
});

test("applique les cinq limites du plan Gratuit", () => {
  assert.deepEqual(subscriptionCreditLimitsForPlan("free", false), {
    journeys: 2,
    pdf: 0,
    voiceAi: 1,
    textAi: 2,
    activeOffers: 3,
  });
});

test("applique les limites ilipresto+ et ilipro", () => {
  const plus = subscriptionCreditLimitsForPlan("ilipresto_plus", false);
  const pro = subscriptionCreditLimitsForPlan("ilipro", false);
  assert.equal(plus.journeys, 5);
  assert.equal(plus.pdf, 5);
  assert.equal(plus.voiceAi, 5);
  assert.equal(plus.textAi, UNLIMITED_SUBSCRIPTION_CREDIT);
  assert.equal(pro.journeys, 10);
  assert.equal(pro.pdf, 10);
  assert.equal(pro.voiceAi, UNLIMITED_SUBSCRIPTION_CREDIT);
  assert.equal(pro.activeOffers, 30);
});

test("le mode gratuit complet rend tous les crédits illimités", () => {
  for (const plan of ["free", "ilipresto_plus", "ilipro"] as const) {
    const limits = subscriptionCreditLimitsForPlan(plan, true);
    for (const limit of Object.values(limits)) {
      assert.equal(limit, UNLIMITED_SUBSCRIPTION_CREDIT);
    }
  }
});

test("le mois de consommation utilise UTC", () => {
  assert.equal(subscriptionCreditPeriod(new Date("2026-07-31T23:59:59Z")), "2026-07");
  assert.equal(subscriptionCreditPeriod(new Date("2026-08-01T00:00:00Z")), "2026-08");
});

test("compte uniquement les annonces réellement actives", () => {
  assert.equal(isSubscriptionCreditActiveListing({ status: "active" }), true);
  assert.equal(isSubscriptionCreditActiveListing({ isPublished: true }), true);
  assert.equal(
    isSubscriptionCreditActiveListing({ visibility: { isPublic: true } }),
    true,
  );
  assert.equal(
    isSubscriptionCreditActiveListing({ status: "archived", isPublished: true }),
    false,
  );
  assert.equal(
    isSubscriptionCreditActiveListing({ status: "active", deletedAt: "2026-01-01" }),
    false,
  );
});
