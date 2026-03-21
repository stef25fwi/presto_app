import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";

export async function moveJobToDeadLetter(jobId: string, reason: string): Promise<void> {
  await db.collection(COLLECTIONS.emailJobs).doc(jobId).set(
    {
      status: "dead_letter",
      dead_letter_reason: reason,
      updated_at: Date.now(),
    },
    { merge: true },
  );
}
