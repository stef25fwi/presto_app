import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";

export async function moveJobToDeadLetter(jobId: string, reason: string): Promise<void> {
  const now = Date.now();
  await db.collection(COLLECTIONS.emailJobs).doc(jobId).set(
    {
      status: "dead_letter",
      dead_letter_reason: reason,
      updated_at: now,
    },
    { merge: true },
  );

  await db.collection(COLLECTIONS.audits).add({
    action: "email.job.dead_letter",
    job_id: jobId,
    reason,
    created_at: now,
  });
}
