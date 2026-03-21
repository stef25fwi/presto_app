"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onReportCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
exports.onReportCreated = (0, firestore_1.onDocumentCreated)("reports/{reportId}", async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
    const reporterId = String(data.reporter_id || "");
    const user = await firestore_2.db.collection(constants_1.COLLECTIONS.users).doc(reporterId).get();
    const email = String(user.data()?.email || "").trim();
    if (!email)
        return;
    const reportId = event.params.reportId;
    const now = Date.now();
    const eventId = `evt_report_created_${reportId}_${now}`;
    await firestore_2.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "report.created",
        source_collection: constants_1.COLLECTIONS.reports,
        source_id: reportId,
        recipient_user_id: reporterId,
        dedupe_key: (0, hash_1.sha256)(`report.created:${reportId}`),
        occurred_at: now,
        payload: {
            recipient_email: email,
            reportId,
            reportUrl: `https://presto.app/support/reports/${reportId}`,
        },
        status: "created",
    });
});
//# sourceMappingURL=triggers.js.map