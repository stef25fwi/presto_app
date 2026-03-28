"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.trackProductEventBackend = trackProductEventBackend;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
function sanitizeParams(params) {
    const result = {};
    for (const [key, value] of Object.entries(params)) {
        if (value == null) {
            result[key] = null;
            continue;
        }
        if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
            result[key] = value;
            continue;
        }
        result[key] = String(value);
    }
    return result;
}
function dateKeyFromDate(date) {
    return date.toISOString().slice(0, 10);
}
async function trackProductEventBackend({ eventName, userId, listingId, threadId, params = {}, }) {
    const sanitizedParams = sanitizeParams(params);
    logger_1.logger.info("marketplace_product_event", {
        eventName,
        userId,
        listingId,
        threadId,
        ...sanitizedParams,
    });
    const now = new Date();
    const dateKey = dateKeyFromDate(now);
    const snapshotId = `${dateKey}_marketplace`;
    await firestore_1.db.collection(constants_1.COLLECTIONS.analyticsSnapshots).doc(snapshotId).set({
        id: snapshotId,
        dateKey,
        metricGroup: "marketplace",
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        [`metrics.${eventName}`]: firebase_admin_1.default.firestore.FieldValue.increment(1),
    }, { merge: true });
}
//# sourceMappingURL=analytics.js.map