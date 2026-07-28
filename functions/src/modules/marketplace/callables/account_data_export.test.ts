import assert from "node:assert/strict";
import test from "node:test";

import { serializeFirestoreValue } from "./account_data_export";

test("serializeFirestoreValue passes primitives through unchanged", () => {
  assert.equal(serializeFirestoreValue("hello"), "hello");
  assert.equal(serializeFirestoreValue(42), 42);
  assert.equal(serializeFirestoreValue(true), true);
  assert.equal(serializeFirestoreValue(null), null);
  assert.equal(serializeFirestoreValue(undefined), undefined);
});

test("serializeFirestoreValue converts Firestore Timestamp-like values to ISO strings", () => {
  const timestampLike = {
    toDate: () => new Date("2026-07-28T10:00:00.000Z"),
  };

  assert.equal(
    serializeFirestoreValue(timestampLike),
    "2026-07-28T10:00:00.000Z",
  );
});

test("serializeFirestoreValue recurses into arrays and nested objects", () => {
  const timestampLike = {
    toDate: () => new Date("2026-07-28T10:00:00.000Z"),
  };

  const input = {
    title: "Annonce",
    createdAt: timestampLike,
    tags: ["a", "b"],
    media: [
      { uploadedAt: timestampLike, url: "https://cdn.example/1.jpg" },
    ],
  };

  assert.deepEqual(serializeFirestoreValue(input), {
    title: "Annonce",
    createdAt: "2026-07-28T10:00:00.000Z",
    tags: ["a", "b"],
    media: [
      { uploadedAt: "2026-07-28T10:00:00.000Z", url: "https://cdn.example/1.jpg" },
    ],
  });
});
