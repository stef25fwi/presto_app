"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.canProceedRateLimited = canProceedRateLimited;
const firestore_1 = require("./firestore");
const firestore_2 = require("firebase-admin/firestore");
const RATE_LIMIT_TTL_GRACE_MS = 60 * 60 * 1000;
async function canProceedRateLimited(scope, key, limit, windowMs) {
    const now = Date.now();
    const bucket = Math.floor(now / windowMs);
    const bucketEndsAt = (bucket + 1) * windowMs;
    const docId = `${scope}:${key}:${bucket}`;
    const ref = firestore_1.db.collection("_rate_limits").doc(docId);
    // Transaction atomique pour éviter les courses. expiresAt alimente la TTL
    // Firestore déclarée dans firestore.indexes.json afin que la collection ne
    // grossisse pas indéfiniment.
    return firestore_1.db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const count = snap.exists ? Number(snap.data()?.count || 0) : 0;
        if (count >= limit)
            return false;
        tx.set(ref, {
            count: firestore_2.FieldValue.increment(1),
            updated_at: now,
            expiresAt: firestore_2.Timestamp.fromMillis(bucketEndsAt + RATE_LIMIT_TTL_GRACE_MS),
        }, { merge: true });
        return true;
    });
}
//# sourceMappingURL=rate_limit.js.map