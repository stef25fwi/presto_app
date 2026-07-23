import assert from "node:assert/strict";
import test from "node:test";

import { isCommercialBillingEnabled } from "./operating_mode_guard";

test("refuse toute configuration absente ou bêta", () => {
  assert.equal(isCommercialBillingEnabled(undefined), false);
  assert.equal(isCommercialBillingEnabled({}), false);
  assert.equal(isCommercialBillingEnabled({
    operatingMode: "free_beta",
    subscriptionSectionEnabled: true,
    stripeEnabled: true,
    freeAccessMode: false,
  }), false);
});

test("exige les quatre indicateurs commerciaux cohérents", () => {
  const valid = {
    operatingMode: "commercial",
    subscriptionSectionEnabled: true,
    stripeEnabled: true,
    freeAccessMode: false,
  };
  assert.equal(isCommercialBillingEnabled(valid), true);
  assert.equal(isCommercialBillingEnabled({ ...valid, stripeEnabled: false }), false);
  assert.equal(isCommercialBillingEnabled({ ...valid, freeAccessMode: true }), false);
  assert.equal(
    isCommercialBillingEnabled({ ...valid, subscriptionSectionEnabled: false }),
    false,
  );
});
