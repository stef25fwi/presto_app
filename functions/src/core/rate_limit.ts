import { db } from "./firestore";
import { FieldValue } from "firebase-admin/firestore";

export async function canProceedRateLimited(scope: string, key: string, limit: number, windowMs: number): Promise<boolean> {
  const bucket = Math.floor(Date.now() / windowMs);
  const docId = `${scope}:${key}:${bucket}`;
  const ref = db.collection("_rate_limits").doc(docId);

  // Atomic transaction to prevent race conditions
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = snap.exists ? Number(snap.data()?.count || 0) : 0;
    if (count >= limit) return false;
    tx.set(ref, { count: FieldValue.increment(1), updated_at: Date.now() }, { merge: true });
    return true;
  });
}
