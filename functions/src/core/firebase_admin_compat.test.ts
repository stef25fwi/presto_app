import assert from "node:assert/strict";
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

  assert.equal(typeof admin.firestore.FieldValue.serverTimestamp, "function");
  assert.equal(typeof admin.firestore.Timestamp.fromMillis, "function");
  assert.equal(typeof admin.firestore.FieldPath.documentId, "function");
});
