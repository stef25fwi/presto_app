import { FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { db } from "../core/firestore";

export interface MonthlyQuotaReservation {
  metric: string;
  units: number;
  limit: number;
  period?: string;
}

export function monthlyQuotaPeriod(now = new Date()): string {
  return now.toISOString().slice(0, 7);
}

export function assertMonthlyQuotaAvailable(
  currentUnits: number,
  requestedUnits: number,
  limit: number,
): number {
  const current = Number.isFinite(currentUnits) ? Math.max(0, currentUnits) : 0;
  const requested = Number.isFinite(requestedUnits)
    ? Math.max(1, Math.ceil(requestedUnits))
    : 1;
  const normalizedLimit = Number.isFinite(limit) ? Math.max(0, Math.floor(limit)) : 0;
  const next = current + requested;

  if (normalizedLimit === 0 || next > normalizedLimit) {
    throw new HttpsError(
      "resource-exhausted",
      "Le budget mensuel de cette fonctionnalité est atteint. Réessayez le mois prochain.",
    );
  }
  return next;
}

export async function reserveMonthlyUsage({
  metric,
  units,
  limit,
  period = monthlyQuotaPeriod(),
}: MonthlyQuotaReservation): Promise<number> {
  const safeMetric = metric.trim().toLowerCase().replace(/[^a-z0-9_-]/g, "_");
  if (!safeMetric) {
    throw new HttpsError("internal", "Métrique de coût invalide.");
  }

  const documentId = `${safeMetric}_${period}`;
  const reference = db.collection("_cost_usage").doc(documentId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const currentUnits = Number(snapshot.data()?.usedUnits ?? 0);
    const nextUnits = assertMonthlyQuotaAvailable(currentUnits, units, limit);

    transaction.set(reference, {
      metric: safeMetric,
      period,
      usedUnits: nextUnits,
      limit,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return nextUnits;
  });
}
