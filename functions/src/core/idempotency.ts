import { db } from "./firestore";

export async function ensureIdempotent(key: string): Promise<boolean> {
  const ref = db.collection("_idempotency").doc(key);
  const snap = await ref.get();
  if (snap.exists) return false;
  await ref.set({ key, created_at: Date.now() });
  return true;
}
