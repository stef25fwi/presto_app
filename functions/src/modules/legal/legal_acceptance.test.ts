import assert from "node:assert/strict";
import test from "node:test";

import { hasCurrentLegalAcceptance } from "./legal_acceptance";

const legal = {
  operatingMode: "free_beta",
  legalVersion: "beta-free-v1",
  cguVersion: "cgu-beta-free-v1",
  privacyVersion: "privacy-beta-free-v1",
};

test("accepte une version légale courante correspondante", () => {
  assert.equal(
    hasCurrentLegalAcceptance(
      {
        legalAcceptance: {
          operatingMode: "free_beta",
          legalVersion: "beta-free-v1",
          cguVersion: "cgu-beta-free-v1",
          privacyVersion: "privacy-beta-free-v1",
        },
      },
      legal,
    ),
    true,
  );
});

test("refuse une acceptation absente ou obsolète", () => {
  assert.equal(hasCurrentLegalAcceptance({}, legal), false);
  assert.equal(
    hasCurrentLegalAcceptance(
      {
        legalAcceptance: {
          operatingMode: "free_beta",
          legalVersion: "beta-free-v0",
          cguVersion: "cgu-beta-free-v1",
          privacyVersion: "privacy-beta-free-v1",
        },
      },
      legal,
    ),
    false,
  );
});

test("refuse un mode ou une version légale incomplets", () => {
  assert.equal(
    hasCurrentLegalAcceptance(
      {
        legalAcceptance: {
          operatingMode: "commercial",
          legalVersion: "commercial-v1",
          cguVersion: "cgu-commercial-v1",
          privacyVersion: "privacy-commercial-v1",
        },
      },
      legal,
    ),
    false,
  );
  assert.equal(
    hasCurrentLegalAcceptance(
      {
        legalAcceptance: {
          operatingMode: "free_beta",
          legalVersion: "beta-free-v1",
          cguVersion: "cgu-beta-free-v1",
          privacyVersion: "privacy-beta-free-v1",
        },
      },
      {...legal, cguVersion: ""},
    ),
    false,
  );
});
