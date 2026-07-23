import assert from "node:assert/strict";
import test from "node:test";

import {
  hasCurrentCommercialLegalAcceptance,
  isCommercialBillingEnabled,
} from "./operating_mode_guard";

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

test("refuse une acceptation bêta après passage commercial", () => {
  const legal = {
    operatingMode: "commercial",
    legalVersion: "commercial-v1",
    cguVersion: "cgu-commercial-v1",
    privacyVersion: "privacy-commercial-v1",
  };
  const user = {
    legalAcceptance: {
      operatingMode: "free_beta",
      legalVersion: "beta-free-v1",
      cguVersion: "cgu-beta-free-v1",
      privacyVersion: "privacy-beta-free-v1",
    },
  };
  assert.equal(hasCurrentCommercialLegalAcceptance(user, legal), false);
});

test("autorise uniquement les versions commerciales exactes", () => {
  const legal = {
    operatingMode: "commercial",
    legalVersion: "commercial-v1",
    cguVersion: "cgu-commercial-v1",
    privacyVersion: "privacy-commercial-v1",
  };
  const acceptance = {
    operatingMode: "commercial",
    legalVersion: "commercial-v1",
    cguVersion: "cgu-commercial-v1",
    privacyVersion: "privacy-commercial-v1",
  };
  assert.equal(
    hasCurrentCommercialLegalAcceptance(
      { legalAcceptance: acceptance },
      legal,
    ),
    true,
  );
  assert.equal(
    hasCurrentCommercialLegalAcceptance(
      {
        legalAcceptance: {
          ...acceptance,
          cguVersion: "cgu-commercial-v0",
        },
      },
      legal,
    ),
    false,
  );
});
