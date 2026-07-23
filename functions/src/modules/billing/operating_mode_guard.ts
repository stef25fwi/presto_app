import { HttpsError } from "firebase-functions/v2/https";
import { db } from "../../core/firestore";

export type BillingOperatingModeConfig = {
  operatingMode?: unknown;
  subscriptionSectionEnabled?: unknown;
  stripeEnabled?: unknown;
  freeAccessMode?: unknown;
};

export function isCommercialBillingEnabled(
  data: BillingOperatingModeConfig | undefined,
): boolean {
  if (!data) return false;
  return String(data.operatingMode ?? "").trim().toLowerCase() === "commercial"
    && data.subscriptionSectionEnabled === true
    && data.stripeEnabled === true
    && data.freeAccessMode === false;
}

export async function assertCommercialBillingEnabled(): Promise<void> {
  const snapshot = await db.collection("app_config").doc("subscriptions").get();
  if (!isCommercialBillingEnabled(snapshot.data())) {
    throw new HttpsError(
      "failed-precondition",
      "Ilipresto est actuellement en bêta gratuite. Aucun abonnement ou paiement n’est actif.",
    );
  }
}
