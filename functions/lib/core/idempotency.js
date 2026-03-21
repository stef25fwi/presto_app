"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureIdempotent = ensureIdempotent;
const firestore_1 = require("./firestore");
async function ensureIdempotent(key) {
    const ref = firestore_1.db.collection("_idempotency").doc(key);
    const snap = await ref.get();
    if (snap.exists)
        return false;
    await ref.set({ key, created_at: Date.now() });
    return true;
}
//# sourceMappingURL=idempotency.js.map