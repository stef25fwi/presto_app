"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.canProceedRateLimited = canProceedRateLimited;
const firestore_1 = require("./firestore");
async function canProceedRateLimited(scope, key, limit, windowMs) {
    const bucket = Math.floor(Date.now() / windowMs);
    const docId = `${scope}:${key}:${bucket}`;
    const ref = firestore_1.db.collection("_rate_limits").doc(docId);
    const snap = await ref.get();
    const count = snap.exists ? Number(snap.data()?.count || 0) : 0;
    if (count >= limit)
        return false;
    await ref.set({ count: count + 1, updated_at: Date.now() }, { merge: true });
    return true;
}
//# sourceMappingURL=rate_limit.js.map