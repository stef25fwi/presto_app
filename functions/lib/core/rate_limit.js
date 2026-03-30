"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.canProceedRateLimited = canProceedRateLimited;
const firestore_1 = require("./firestore");
const firestore_2 = require("firebase-admin/firestore");
async function canProceedRateLimited(scope, key, limit, windowMs) {
    const bucket = Math.floor(Date.now() / windowMs);
    const docId = `${scope}:${key}:${bucket}`;
    const ref = firestore_1.db.collection("_rate_limits").doc(docId);
    // Atomic transaction to prevent race conditions
    return firestore_1.db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const count = snap.exists ? Number(snap.data()?.count || 0) : 0;
        if (count >= limit)
            return false;
        tx.set(ref, { count: firestore_2.FieldValue.increment(1), updated_at: Date.now() }, { merge: true });
        return true;
    });
}
//# sourceMappingURL=rate_limit.js.map