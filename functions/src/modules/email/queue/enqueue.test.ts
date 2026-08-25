import assert from "node:assert/strict";
import test from "node:test";

import { isActiveSuppression, normalizeSuppressionKey } from "./enqueue";

test("normalizeSuppressionKey aligne la casse et les espaces sur la clé du webhook", () => {
  assert.equal(normalizeSuppressionKey("  User@Gmail.COM "), "user@gmail.com");
  assert.equal(normalizeSuppressionKey("contact@ilipresto.fr"), "contact@ilipresto.fr");
});

test("isActiveSuppression n accepte que les suppressions explicitement actives", () => {
  assert.equal(isActiveSuppression({ active: true, reason: "hard_bounce" }), true);
  assert.equal(isActiveSuppression({ active: false, reason: "hard_bounce" }), false);
  assert.equal(isActiveSuppression({ reason: "hard_bounce" }), false);
  assert.equal(isActiveSuppression(undefined), false);
});
