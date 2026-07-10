import { db } from "./firestore";
import { FieldValue, Timestamp } from "firebase-admin/firestore";

const RATE_LIMIT_TTL_GRACE_MS = 60 * 60 * 1000;

export async function canProceedRateLimited(
  scope: string,
  key: string,
  limit: number,
  windowMs: number,
): Promise<boolean> {
  const now = Date.now();
  const bucket = Math.floor(now / windowMs);
  const bucketEndsAt = (bucket + 1) * windowMs;
  const docId = `${scope}:${key}:${bucket}`;
  const ref = db.collection("_rate_limits").doc(docId);

  // Transaction atomique pour éviter les courses. expiresAt alimente la TTL
  // Firestore déclarée dans firestore.indexes.json afin que la collection ne
  // grossisse pas indéfiniment.
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = snap.exists ? Number(snap.data()?.count || 0) : 0;
    if (count >= limit) return false;

    tx.set(
      ref,
      {
        count: FieldValue.increment(1),
        updated_at: now,
        expiresAt: Timestamp.fromMillis(bucketEndsAt + RATE_LIMIT_TTL_GRACE_MS),
      },
      { merge: true },
    );
    return true;
  });
}
