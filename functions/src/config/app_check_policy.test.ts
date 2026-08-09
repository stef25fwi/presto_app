import assert from "node:assert/strict";
import test from "node:test";

import { resolveAppCheckEnforcement } from "./app_check_policy";

test("désactive App Check dans les émulateurs", () => {
  assert.equal(
    resolveAppCheckEnforcement({
      isEmulator: true,
      isProduction: true,
      enforceValue: "true",
    }),
    false,
  );
});

test("active App Check par défaut en production", () => {
  assert.equal(
    resolveAppCheckEnforcement({
      isEmulator: false,
      isProduction: true,
    }),
    true,
  );
  assert.equal(
    resolveAppCheckEnforcement({
      isEmulator: false,
      isProduction: true,
      enforceValue: "true",
    }),
    true,
  );
});

test("refuse toute désactivation explicite en production", () => {
  assert.equal(
    resolveAppCheckEnforcement({
      isEmulator: false,
      isProduction: true,
      enforceValue: " false ",
    }),
    true,
  );
});

test("exige une activation explicite hors production", () => {
  assert.equal(
    resolveAppCheckEnforcement({
      isEmulator: false,
      isProduction: false,
    }),
    false,
  );
  assert.equal(
    resolveAppCheckEnforcement({
      isEmulator: false,
      isProduction: false,
      enforceValue: "TRUE",
    }),
    true,
  );
});

test("safe mode ne peut pas désactiver App Check en production", () => {
  assert.equal(
    resolveAppCheckEnforcement({
      isEmulator: false,
      isProduction: true,
      enforceValue: "true",
      safeModeValue: "true",
    }),
    true,
  );
});

test("safe mode reste disponible hors production", () => {
  assert.equal(
    resolveAppCheckEnforcement({
      isEmulator: false,
      isProduction: false,
      enforceValue: "true",
      safeModeValue: "true",
    }),
    false,
  );
});
