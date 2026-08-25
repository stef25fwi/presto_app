import assert from "node:assert/strict";
import test from "node:test";

import {
  DEFAULT_DELIVERABILITY_THRESHOLDS,
  computeDeliverabilityRates,
  describeViolation,
  evaluateDeliverability,
  type DeliverabilityStats,
} from "./deliverability";

function stats(overrides: Partial<DeliverabilityStats> = {}): DeliverabilityStats {
  return {
    requests: 1000,
    delivered: 990,
    hardBounces: 2,
    softBounces: 5,
    blocked: 1,
    spamReports: 0,
    invalid: 1,
    deferred: 10,
    unsubscribed: 1,
    ...overrides,
  };
}

test("computeDeliverabilityRates rapporte tous les taux à l échantillon envoyé", () => {
  const rates = computeDeliverabilityRates(stats());

  assert.equal(rates.delivery, 0.99);
  assert.equal(rates.hardBounce, 0.002);
  assert.equal(rates.bounce, 0.007);
  assert.equal(rates.deferred, 0.01);
});

test("computeDeliverabilityRates ne divise pas par zéro", () => {
  const rates = computeDeliverabilityRates(stats({ requests: 0, delivered: 0 }));

  assert.equal(rates.delivery, 0);
  assert.equal(rates.hardBounce, 0);
});

test("evaluateDeliverability accepte un échantillon sain", () => {
  const evaluation = evaluateDeliverability(stats());

  assert.equal(evaluation.ok, true);
  assert.equal(evaluation.evaluated, true);
  assert.deepEqual(evaluation.violations, []);
});

test("evaluateDeliverability n applique pas les seuils sous le volume minimal", () => {
  const evaluation = evaluateDeliverability(stats({ requests: 10, delivered: 9, hardBounces: 1 }));

  assert.equal(evaluation.evaluated, false);
  assert.equal(evaluation.ok, true);
  assert.ok(evaluation.warnings.includes("sample_below_threshold"));
  assert.ok(evaluation.warnings.includes("hard_bounce_observed"));
});

test("evaluateDeliverability détecte un taux de hard bounce trop élevé", () => {
  const evaluation = evaluateDeliverability(stats({ hardBounces: 30, delivered: 960 }));

  assert.equal(evaluation.ok, false);
  assert.ok(evaluation.violations.some((item) => item.metric === "hardBounce"));
});

test("evaluateDeliverability détecte une plainte au-dessus du seuil", () => {
  const evaluation = evaluateDeliverability(stats({ spamReports: 5 }));

  assert.equal(evaluation.ok, false);
  const violation = evaluation.violations.find((item) => item.metric === "complaint");
  assert.ok(violation);
  assert.equal(violation?.threshold, DEFAULT_DELIVERABILITY_THRESHOLDS.maxComplaintRate);
});

test("evaluateDeliverability détecte un taux de livraison insuffisant", () => {
  const evaluation = evaluateDeliverability(stats({ delivered: 900, softBounces: 40 }));

  assert.equal(evaluation.ok, false);
  const violation = evaluation.violations.find((item) => item.metric === "delivery");
  assert.equal(violation?.direction, "min");
});

test("evaluateDeliverability accepte des seuils personnalisés", () => {
  const evaluation = evaluateDeliverability(stats({ spamReports: 5 }), {
    ...DEFAULT_DELIVERABILITY_THRESHOLDS,
    maxComplaintRate: 0.01,
  });

  assert.equal(evaluation.ok, true);
});

test("describeViolation formate un dépassement lisible", () => {
  const evaluation = evaluateDeliverability(stats({ hardBounces: 30, delivered: 960 }));
  const violation = evaluation.violations.find((item) => item.metric === "hardBounce");

  assert.ok(violation);
  assert.match(describeViolation(violation!), /^hardBounce 3\.000% > 2\.000%$/);
});
