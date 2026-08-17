export const PUBLIC_PROFILE_CONSENT_VERSION = "public-profile-v1-2026-08-17";

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

export function hasValidPublicProfileConsent(
  data: Record<string, unknown> | undefined,
): boolean {
  if (!data) return false;
  return data.enabled === true
    && boundedText(data.version, 80) === PUBLIC_PROFILE_CONSENT_VERSION
    && boundedText(data.source, 80) === "authenticated_user_callable";
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

export function canPublishPublicProfessionalProfile(
  profile: Record<string, unknown>,
  consent: Record<string, unknown> | undefined,
): boolean {
  return isEligibleForPublicProfessionalProfile(profile)
    && hasValidPublicProfileConsent(consent);
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
