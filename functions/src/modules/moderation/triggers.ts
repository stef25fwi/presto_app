import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import { sha256 } from "../../utils/hash";

export const onReportCreated = onDocumentCreated("reports/{reportId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const reporterId = String(data.reporter_id || "");
  const user = await db.collection(COLLECTIONS.users).doc(reporterId).get();
  const email = String(user.data()?.email || "").trim();
  if (!email) return;

  const reportId = event.params.reportId;
  const now = Date.now();
  const eventId = `evt_report_created_${reportId}_${now}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: "report.created",
    source_collection: COLLECTIONS.reports,
    source_id: reportId,
    recipient_user_id: reporterId,
    dedupe_key: sha256(`report.created:${reportId}`),
    occurred_at: now,
    payload: {
      recipient_email: email,
      reportId,
      reportUrl: `https://presto.app/support/reports/${reportId}`,
    },
    status: "created",
  });
});

export const onReportUpdated = onDocumentUpdated("reports/{reportId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const beforeStatus = String(before.status || "").trim().toLowerCase();
  const afterStatus = String(after.status || "").trim().toLowerCase();
  if (beforeStatus === afterStatus || afterStatus !== "resolved") return;

  const reporterId = String(after.reporter_id || "");
  if (!reporterId) return;

  const user = await db.collection(COLLECTIONS.users).doc(reporterId).get();
  const email = String(user.data()?.email || "").trim();
  if (!email) return;

  const reportId = event.params.reportId;
  const now = Date.now();
  const eventId = `evt_report_resolved_${reportId}_${now}`;

  await db.collection(COLLECTIONS.emailEvents).doc(eventId).set({
    event_id: eventId,
    event_name: "report.resolved",
    source_collection: COLLECTIONS.reports,
    source_id: reportId,
    recipient_user_id: reporterId,
    dedupe_key: sha256(`report.resolved:${reportId}:${String(after.resolved_at || after.updated_at || now)}`),
    occurred_at: now,
    payload: {
      recipient_email: email,
      firstName: String(user.data()?.displayName || user.data()?.display_name || "").split(" ")[0] || "",
      reportId,
      reportUrl: `https://presto.app/support/reports/${reportId}`,
      resolutionSummary: String(after.resolution_summary || after.resolutionSummary || after.moderator_note || "Votre signalement a été traité par notre équipe."),
    },
    status: "created",
  });
});
