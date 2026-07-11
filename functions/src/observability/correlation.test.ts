import assert from "node:assert/strict";
import test from "node:test";

import {
  buildOperationLogContext,
  normalizeCorrelationId,
  resolveCorrelationId,
} from "./correlation";

test("accepte uniquement les identifiants de corrélation sûrs", () => {
  assert.equal(normalizeCorrelationId(" request-1234 "), "request-1234");
  assert.equal(normalizeCorrelationId("short"), null);
  assert.equal(normalizeCorrelationId("invalid id with spaces"), null);
  assert.equal(normalizeCorrelationId("<script>alert(1)</script>"), null);
});

test("génère un UUID lorsque la valeur cliente est invalide", () => {
  const generated = resolveCorrelationId("");
  assert.match(
    generated,
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
  );
});

test("construit un contexte de log normalisé", () => {
  assert.deepEqual(
    buildOperationLogContext({
      correlationId: "request-1234",
      operation: " admin_bulk_delete_listings ",
      actorId: " admin-1 ",
    }),
    {
      correlationId: "request-1234",
      operation: "admin_bulk_delete_listings",
      actorId: "admin-1",
    },
  );
});

test("refuse un contexte sans nom d opération", () => {
  assert.throws(
    () =>
      buildOperationLogContext({
        correlationId: "request-1234",
        operation: "   ",
      }),
    /operation is required/,
  );
});
