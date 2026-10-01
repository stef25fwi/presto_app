import { HttpsError } from "firebase-functions/v2/https";
import { db } from "../../core/firestore";

type LegalVersionRecord = {
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

export function hasCurrentLegalAcceptance(
  userData: Record<string, unknown> | undefined,
  legalData: LegalVersionRecord | undefined,
): boolean {
  if (!userData || !legalData) return false;

  const mode = normalized(legalData.operatingMode).toLowerCase();
  if (mode !== "free_beta" && mode !== "commercial") return false;

  const legalVersion = normalized(legalData.legalVersion);
  const cguVersion = normalized(legalData.cguVersion);
  const privacyVersion = normalized(legalData.privacyVersion);
  if (!legalVersion || !cguVersion || !privacyVersion) return false;

  const acceptance = asRecord(userData.legalAcceptance);
  return normalized(acceptance.operatingMode).toLowerCase() === mode
    && normalized(acceptance.legalVersion) === legalVersion
    && normalized(acceptance.cguVersion) === cguVersion
    && normalized(acceptance.privacyVersion) === privacyVersion;
}

export async function assertCurrentLegalAcceptance(userId: string): Promise<void> {
  const uid = userId.trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Connexion requise pour publier");
  }

  const [legalSnapshot, userSnapshot] = await Promise.all([
    db.collection("app_config").doc("legal").get(),
    db.collection("users").doc(uid).get(),
  ]);

  if (!hasCurrentLegalAcceptance(userSnapshot.data(), legalSnapshot.data())) {
    throw new HttpsError(
      "failed-precondition",
      "Acceptez les CGU et la politique de confidentialité en vigueur avant de publier.",
    );
  }
}
