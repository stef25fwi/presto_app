"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const listings_1 = require("./listings");
(0, node_test_1.default)("publishes approved pending listings once the 1 minute delay has elapsed", () => {
    const now = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_060_000);
    const oneMinuteEarlier = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_000_000);
    const ready = (0, listings_1.isListingReadyForScheduledPublication)({
        status: "pending",
        moderationStatus: "approved",
        mediaProcessingStatus: "completed",
        autoPublishAfter: oneMinuteEarlier,
    }, now);
    strict_1.default.equal(ready, true);
});
(0, node_test_1.default)("does not publish auto_flagged pending listings once the delay has elapsed", () => {
    const now = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_060_000);
    const oneMinuteEarlier = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_000_000);
    const ready = (0, listings_1.isListingReadyForScheduledPublication)({
        status: "pending",
        moderationStatus: "auto_flagged",
        mediaProcessingStatus: "completed",
        autoPublishAfter: oneMinuteEarlier,
    }, now);
    strict_1.default.equal(ready, false);
});
(0, node_test_1.default)("does not publish manual_review pending listings once the delay has elapsed", () => {
    const now = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_060_000);
    const oneMinuteEarlier = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_000_000);
    const ready = (0, listings_1.isListingReadyForScheduledPublication)({
        status: "pending",
        moderationStatus: "manual_review",
        mediaProcessingStatus: "",
        autoPublishAfter: oneMinuteEarlier,
    }, now);
    strict_1.default.equal(ready, false);
});
(0, node_test_1.default)("does not publish approved pending listings before the 1 minute delay elapses", () => {
    const now = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_000_000);
    const oneMinuteLater = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_060_000);
    const ready = (0, listings_1.isListingReadyForScheduledPublication)({
        status: "pending",
        moderationStatus: "approved",
        mediaProcessingStatus: "completed",
        autoPublishAfter: oneMinuteLater,
    }, now);
    strict_1.default.equal(ready, false);
});
(0, node_test_1.default)("does not publish while media processing is incomplete", () => {
    const now = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_060_000);
    const oneMinuteEarlier = firebase_admin_1.default.firestore.Timestamp.fromMillis(1_700_000_000_000);
    const ready = (0, listings_1.isListingReadyForScheduledPublication)({
        status: "pending",
        moderationStatus: "approved",
        mediaProcessingStatus: "processing",
        autoPublishAfter: oneMinuteEarlier,
    }, now);
    strict_1.default.equal(ready, false);
});
//# sourceMappingURL=listings.test.js.map