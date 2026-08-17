export interface PublicProfessionalProfileProjection {
  companyName: string;
  city: string;
  activityCode: string;
  verifiedProfessional: true;
  visibility: "public";
}

function boundedText(value: unknown, maxLength: number): string {
  return String(value ?? "")
    .replace(/[\u0000-\u001F\u007F]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function readBoolean(value: unknown): boolean {
  return value === true;
}

export function isEligibleForPublicProfessionalProfile(
  data: Record<string, unknown>,
): boolean {
  return readBoolean(data.publicProfileEnabled)
    && readBoolean(data.siretVerified)
    && readBoolean(data.establishmentActive)
    && boundedText(data.proStatus, 48).toLowerCase() === "verified_siret"
    && boundedText(data.companyName, 160).length >= 2
    && boundedText(data.city, 120).length >= 2;
}

/**
 * Builds the only payload that may leave the private `pro_profiles` collection.
 * Deliberately excludes SIRET/SIREN, address, postal code, phone, email,
 * verification timestamps/sources and every billing/moderation field.
 */
export function buildPublicProfessionalProfileProjection(
  data: Record<string, unknown>,
): PublicProfessionalProfileProjection | null {
  if (!isEligibleForPublicProfessionalProfile(data)) return null;

  return {
    companyName: boundedText(data.companyName, 160),
    city: boundedText(data.city, 120),
    activityCode: boundedText(data.nafCode, 24),
    verifiedProfessional: true,
    visibility: "public",
  };
}
