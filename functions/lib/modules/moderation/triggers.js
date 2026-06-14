"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onReportUpdated = exports.onReportCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const firestore_3 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
exports.onReportCreated = (0, firestore_1.onDocumentCreated)("reports/{reportId}", async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
    const reporterId = String(data.reporter_id || "");
    const user = await firestore_3.db.collection(constants_1.COLLECTIONS.users).doc(reporterId).get();
    const email = String(user.data()?.email || "").trim();
    if (!email)
        return;
    const reportId = event.params.reportId;
    const now = Date.now();
    const eventId = `evt_report_created_${reportId}_${now}`;
    await firestore_3.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
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
            reportUrl: `https://ilipresto.fr/support/reports/${reportId}`,
        },
        status: "created",
    });
});
exports.onReportUpdated = (0, firestore_2.onDocumentUpdated)("reports/{reportId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after)
        return;
    const beforeStatus = String(before.status || "").trim().toLowerCase();
    const afterStatus = String(after.status || "").trim().toLowerCase();
    if (beforeStatus === afterStatus || afterStatus !== "resolved")
        return;
    const reporterId = String(after.reporter_id || "");
    if (!reporterId)
        return;
    const user = await firestore_3.db.collection(constants_1.COLLECTIONS.users).doc(reporterId).get();
    const email = String(user.data()?.email || "").trim();
    if (!email)
        return;
    const reportId = event.params.reportId;
    const now = Date.now();
    const eventId = `evt_report_resolved_${reportId}_${now}`;
    await firestore_3.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "report.resolved",
        source_collection: constants_1.COLLECTIONS.reports,
        source_id: reportId,
        recipient_user_id: reporterId,
        dedupe_key: (0, hash_1.sha256)(`report.resolved:${reportId}:${String(after.resolved_at || after.updated_at || now)}`),
        occurred_at: now,
        payload: {
            recipient_email: email,
            firstName: String(user.data()?.displayName || user.data()?.display_name || "").split(" ")[0] || "",
            reportId,
            reportUrl: `https://ilipresto.fr/support/reports/${reportId}`,
            resolutionSummary: String(after.resolution_summary || after.resolutionSummary || after.moderator_note || "Votre signalement a été traité par notre équipe."),
        },
        status: "created",
    });
});
//# sourceMappingURL=triggers.js.map