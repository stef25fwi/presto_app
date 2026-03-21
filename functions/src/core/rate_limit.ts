import { db } from "./firestore";

export async function canProceedRateLimited(scope: string, key: string, limit: number, windowMs: number): Promise<boolean> {
  const bucket = Math.floor(Date.now() / windowMs);
  const docId = `${scope}:${key}:${bucket}`;
  const ref = db.collection("_rate_limits").doc(docId);
  const snap = await ref.get();
  const count = snap.exists ? Number(snap.data()?.count || 0) : 0;
  if (count >= limit) return false;
  await ref.set({ count: count + 1, updated_at: Date.now() }, { merge: true });
  return true;
}
