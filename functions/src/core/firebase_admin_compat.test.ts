import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import admin from "./firebase_admin_compat";

test("Firebase Admin v14 compatibility facade preserves required runtime APIs", () => {
  assert.ok(Array.isArray(admin.apps));
  assert.equal(typeof admin.initializeApp, "function");
  assert.equal(typeof admin.app, "function");
  assert.equal(typeof admin.firestore, "function");
  assert.equal(typeof admin.auth, "function");
  assert.equal(typeof admin.storage, "function");
  assert.equal(typeof admin.messaging, "function");
  assert.equal(typeof admin.remoteConfig, "function");

  assert.equal(typeof admin.firestore.FieldValue.serverTimestamp, "function");
  assert.equal(typeof admin.firestore.Timestamp.fromMillis, "function");
  assert.equal(typeof admin.firestore.FieldPath.documentId, "function");
});

// La façade doit couvrir tout ce que l'entrypoint legacy consomme : une méthode
// oubliée ne casse rien à la compilation et ne se voit qu'à l'exécution, en
// production. C'est ainsi que `remoteConfig` avait disparu, faisant échouer
// silencieusement toute la configuration Remote Config du micro-IA.
test("Firebase Admin facade covers every admin.* member used by the legacy entrypoint", () => {
  const legacySource = readFileSync(
    join(__dirname, "..", "..", "index.js"),
    "utf8",
  );
  const used = new Set(
    [...legacySource.matchAll(/\badmin\.([a-zA-Z]+)/g)].map(
      (match) => match[1] as string,
    ),
  );

  assert.ok(used.size > 0, "no admin.* usage found in the legacy entrypoint");

  const missing = [...used].filter(
    (member) => (admin as Record<string, unknown>)[member] === undefined,
  );

  assert.deepEqual(
    missing,
    [],
    `firebase_admin_compat is missing: ${missing.join(", ")}`,
  );
});
