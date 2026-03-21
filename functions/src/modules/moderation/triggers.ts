import { onDocumentCreated } from "firebase-functions/v2/firestore";
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
