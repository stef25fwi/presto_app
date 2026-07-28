import assert from "node:assert/strict";
import test from "node:test";

import {
  buildIdempotencyDocumentId,
  deriveClientRequestId,
  normalizeClientRequestId,
} from "./idempotency";

test("normalizeClientRequestId removes unsafe characters and limits length", () => {
  const normalized = normalizeClientRequestId(`  request / utilisateur ? ${"x".repeat(220)}  `);

  assert.match(normalized, /^[a-zA-Z0-9_.:-]+$/);
  assert.ok(normalized.length <= 180);
});

test("deriveClientRequestId is stable for identical inputs", () => {
  const first = deriveClientRequestId(["texte", "Baie-Mahault", "Jardinage"]);
  const second = deriveClientRequestId(["texte", "Baie-Mahault", "Jardinage"]);
  const different = deriveClientRequestId(["texte", "Les Abymes", "Jardinage"]);

  assert.equal(first, second);
  assert.notEqual(first, different);
  assert.equal(first.length, 40);
});

test("idempotency document id separates users and operations", () => {
  const base = buildIdempotencyDocumentId("user-a", "draft", "request-1");
  const otherUser = buildIdempotencyDocumentId("user-b", "draft", "request-1");
  const otherOperation = buildIdempotencyDocumentId("user-a", "vision", "request-1");

  assert.notEqual(base, otherUser);
  assert.notEqual(base, otherOperation);
  assert.equal(base.length, 64);
});
