import assert from "node:assert/strict";
import test from "node:test";

import {
  parseCostBoolean,
  parseCostInteger,
  resolveCostPolicy,
} from "./cost_policy";

test("minimum cost mode is safe by default", () => {
  const policy = resolveCostPolicy({});
  assert.equal(policy.minimumCostMode, true);
  assert.equal(policy.minInstances, 0);
  assert.equal(policy.microIaProviderMode, "GOOGLE_ONLY");
  assert.equal(policy.microIaFallbackEnabled, false);
  assert.equal(policy.microIaMonthlyAudioSeconds, 3600);
  assert.equal(policy.veoGenerationEnabled, false);
  assert.equal(policy.veoMonthlyGenerationLimit, 0);
});

test("minimum mode cannot accidentally enable warm instances or Veo", () => {
  const policy = resolveCostPolicy({
    MINIMUM_COST_MODE: "true",
    FUNCTIONS_MIN_INSTANCES: "5",
    VEO_GENERATION_ENABLED: "true",
    VEO_MONTHLY_GENERATION_LIMIT: "500",
    MICROIA_PROVIDER_MODE: "HYBRID",
    MICROIA_FALLBACK_ENABLED: "true",
  });
  assert.equal(policy.minInstances, 0);
  assert.equal(policy.veoGenerationEnabled, false);
  assert.equal(policy.microIaProviderMode, "GOOGLE_ONLY");
  assert.equal(policy.microIaFallbackEnabled, false);
});

test("paid mode accepts explicit bounded overrides", () => {
  const policy = resolveCostPolicy({
    MINIMUM_COST_MODE: "false",
    FUNCTIONS_MIN_INSTANCES: "1",
    VEO_GENERATION_ENABLED: "true",
    VEO_MONTHLY_GENERATION_LIMIT: "12",
    MICROIA_PROVIDER_MODE: "HYBRID",
    MICROIA_FALLBACK_ENABLED: "true",
  });
  assert.equal(policy.minInstances, 1);
  assert.equal(policy.veoGenerationEnabled, true);
  assert.equal(policy.veoMonthlyGenerationLimit, 12);
  assert.equal(policy.microIaProviderMode, "HYBRID");
  assert.equal(policy.microIaFallbackEnabled, true);
});

test("parsers reject ambiguous and out-of-range values", () => {
  assert.equal(parseCostBoolean("yes", false), true);
  assert.equal(parseCostBoolean("invalid", false), false);
  assert.equal(parseCostInteger("100", 5, 0, 10), 10);
  assert.equal(parseCostInteger("invalid", 5, 0, 10), 5);
});
