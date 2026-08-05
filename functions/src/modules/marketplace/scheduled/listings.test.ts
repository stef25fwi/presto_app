import assert from "node:assert/strict";
import test from "node:test";
import admin from "../../../core/firebase_admin_compat";

import { isListingReadyForScheduledPublication } from "./listings";

test("publishes approved pending listings once the 30 second delay has elapsed", () => {
  const now = admin.firestore.Timestamp.fromMillis(1_700_000_030_000);
  const thirtySecondsEarlier = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);

  const ready = isListingReadyForScheduledPublication({
    status: "pending",
    moderationStatus: "approved",
    mediaProcessingStatus: "completed",
    autoPublishAfter: thirtySecondsEarlier,
  }, now);

  assert.equal(ready, true);
});

test("does not publish auto_flagged pending listings once the delay has elapsed", () => {
  const now = admin.firestore.Timestamp.fromMillis(1_700_000_030_000);
  const thirtySecondsEarlier = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);

  const ready = isListingReadyForScheduledPublication({
    status: "pending",
    moderationStatus: "auto_flagged",
    mediaProcessingStatus: "completed",
    autoPublishAfter: thirtySecondsEarlier,
  }, now);

  assert.equal(ready, false);
});

test("does not publish manual_review pending listings once the delay has elapsed", () => {
  const now = admin.firestore.Timestamp.fromMillis(1_700_000_030_000);
  const thirtySecondsEarlier = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);

  const ready = isListingReadyForScheduledPublication({
    status: "pending",
    moderationStatus: "manual_review",
    mediaProcessingStatus: "",
    autoPublishAfter: thirtySecondsEarlier,
  }, now);

  assert.equal(ready, false);
});

test("does not publish approved pending listings before the 30 second delay elapses", () => {
  const now = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);
  const thirtySecondsLater = admin.firestore.Timestamp.fromMillis(1_700_000_030_000);

  const ready = isListingReadyForScheduledPublication({
    status: "pending",
    moderationStatus: "approved",
    mediaProcessingStatus: "completed",
    autoPublishAfter: thirtySecondsLater,
  }, now);

  assert.equal(ready, false);
});

test("does not publish while media processing is incomplete", () => {
  const now = admin.firestore.Timestamp.fromMillis(1_700_000_030_000);
  const thirtySecondsEarlier = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);

  const ready = isListingReadyForScheduledPublication({
    status: "pending",
    moderationStatus: "approved",
    mediaProcessingStatus: "processing",
    autoPublishAfter: thirtySecondsEarlier,
  }, now);

  assert.equal(ready, false);
});