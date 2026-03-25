"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onLegalTermsSettingsUpdated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
async function emitTermsUpdatedEvents(version, effectiveDate, termsUrl) {
    let lastDocId;
    while (true) {
        let query = firestore_2.db.collection(constants_1.COLLECTIONS.users).orderBy("__name__").limit(200);
        if (lastDocId) {
            query = query.startAfter(lastDocId);
        }
        const snap = await query.get();
        if (snap.empty)
            break;
        for (const doc of snap.docs) {
            lastDocId = doc.id;
            const user = doc.data() ?? {};
            const recipientEmail = String(user.email || "").trim().toLowerCase();
            if (!recipientEmail)
                continue;
            const eventId = `evt_legal_terms_updated_${version}_${doc.id}`;
            await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
                event_id: eventId,
                event_name: "legal.terms.updated",
                source_collection: constants_1.COLLECTIONS.systemSettings,
                source_id: "legal_terms",
                recipient_user_id: doc.id,
                dedupe_key: (0, hash_1.sha256)(`legal.terms.updated:${version}:${doc.id}`),
                occurred_at: Date.now(),
                payload: {
                    recipient_email: recipientEmail,
                    firstName: String(user.displayName || user.display_name || "").split(" ")[0] || "",
                    effectiveDate,
                    termsUrl,
                },
                status: "created",
            }, { merge: true });
        }
        if (snap.size < 200)
            break;
    }
}
exports.onLegalTermsSettingsUpdated = (0, firestore_1.onDocumentUpdated)(`${constants_1.COLLECTIONS.systemSettings}/legal_terms`, async (event) => {
    const before = (event.data?.before.data() ?? {});
    const after = (event.data?.after.data() ?? {});
    const nextVersion = String(after.current_version || "").trim();
    const previousVersion = String(before.current_version || "").trim();
    const effectiveDate = String(after.effective_date || "").trim();
    const termsUrl = String(after.terms_url || "").trim();
    const status = String(after.status || "draft").trim().toLowerCase();
    if (!nextVersion || nextVersion === previousVersion)
        return;
    if (status !== "published")
        return;
    if (!effectiveDate || !termsUrl)
        return;
    await emitTermsUpdatedEvents(nextVersion, effectiveDate, termsUrl);
});
//# sourceMappingURL=triggers.js.map