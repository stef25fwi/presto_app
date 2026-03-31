import assert from "node:assert/strict";
import test from "node:test";
import admin from "firebase-admin";

import { isListingReadyForScheduledPublication } from "./listings";

test("publishes approved pending listings once the 1 minute delay has elapsed", () => {
  const now = admin.firestore.Timestamp.fromMillis(1_700_000_060_000);
  const oneMinuteEarlier = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);

  const ready = isListingReadyForScheduledPublication({
    status: "pending",
    moderationStatus: "approved",
    mediaProcessingStatus: "completed",
    autoPublishAfter: oneMinuteEarlier,
  }, now);

  assert.equal(ready, true);
});

test("does not publish approved pending listings before the 1 minute delay elapses", () => {
  const now = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);
  const oneMinuteLater = admin.firestore.Timestamp.fromMillis(1_700_000_060_000);

  const ready = isListingReadyForScheduledPublication({
    status: "pending",
    moderationStatus: "approved",
    mediaProcessingStatus: "completed",
    autoPublishAfter: oneMinuteLater,
  }, now);

  assert.equal(ready, false);
});

test("does not publish while media processing is incomplete", () => {
  const now = admin.firestore.Timestamp.fromMillis(1_700_000_060_000);
  const oneMinuteEarlier = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);

  const ready = isListingReadyForScheduledPublication({
    status: "pending",
    moderationStatus: "approved",
    mediaProcessingStatus: "processing",
    autoPublishAfter: oneMinuteEarlier,
  }, now);

  assert.equal(ready, false);
});