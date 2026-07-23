import { HttpsError } from "firebase-functions/v2/https";
import { db } from "../../core/firestore";

export type BillingOperatingModeConfig = {
  operatingMode?: unknown;
  subscriptionSectionEnabled?: unknown;
  stripeEnabled?: unknown;
  freeAccessMode?: unknown;
};

export type ActiveLegalVersions = {
  operatingMode?: unknown;
  legalVersion?: unknown;
  cguVersion?: unknown;
  privacyVersion?: unknown;
};

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function normalized(value: unknown): string {
  return String(value ?? "").trim();
}

export function isCommercialBillingEnabled(
  data: BillingOperatingModeConfig | undefined,
): boolean {
  if (!data) return false;
  return normalized(data.operatingMode).toLowerCase() === "commercial"
    && data.subscriptionSectionEnabled === true
    && data.stripeEnabled === true
    && data.freeAccessMode === false;
}

export function hasCurrentCommercialLegalAcceptance(
  userData: Record<string, unknown> | undefined,
  legalData: ActiveLegalVersions | undefined,
): boolean {
  if (!userData || !legalData) return false;
  if (normalized(legalData.operatingMode).toLowerCase() !== "commercial") {
    return false;
  }
  const acceptance = asRecord(userData.legalAcceptance);
  return normalized(acceptance.operatingMode) === "commercial"
    && normalized(acceptance.legalVersion) === normalized(legalData.legalVersion)
    && normalized(acceptance.cguVersion) === normalized(legalData.cguVersion)
    && normalized(acceptance.privacyVersion) === normalized(legalData.privacyVersion)
    && normalized(legalData.legalVersion).length > 0
    && normalized(legalData.cguVersion).length > 0
    && normalized(legalData.privacyVersion).length > 0;
}

export async function assertCommercialBillingEnabled(
  userId: string,
): Promise<void> {
  const uid = userId.trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Connexion requise pour s’abonner");
  }

  const [subscriptionSnapshot, legalSnapshot, userSnapshot] = await Promise.all([
    db.collection("app_config").doc("subscriptions").get(),
    db.collection("app_config").doc("legal").get(),
    db.collection("users").doc(uid).get(),
  ]);

  if (!isCommercialBillingEnabled(subscriptionSnapshot.data())) {
    throw new HttpsError(
      "failed-precondition",
      "Ilipresto est actuellement en bêta gratuite. Aucun abonnement ou paiement n’est actif.",
    );
  }

  if (!hasCurrentCommercialLegalAcceptance(
    userSnapshot.data(),
    legalSnapshot.data(),
  )) {
    throw new HttpsError(
      "failed-precondition",
      "Acceptez les conditions commerciales et la politique de confidentialité actives avant de souscrire.",
    );
  }
}
