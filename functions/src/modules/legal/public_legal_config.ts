import { onCall } from "firebase-functions/v2/https";
import { PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";

type UnknownMap = Record<string, unknown>;

const BETA_EFFECTIVE_DATE = "2026-07-23T00:00:00.000Z";

function asMap(value: unknown): UnknownMap {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownMap
    : {};
}

function limitedString(value: unknown, maxLength: number, fallback = ""): string {
  const normalized = String(value ?? "").trim();
  return (normalized || fallback).slice(0, maxLength);
}

function isoDate(value: unknown, fallback: string): string {
  if (value && typeof value === "object" && "toDate" in value) {
    const candidate = value as { toDate?: () => Date };
    const date = candidate.toDate?.();
    if (date instanceof Date && Number.isFinite(date.getTime())) {
      return date.toISOString();
    }
  }
  if (value instanceof Date && Number.isFinite(value.getTime())) {
    return value.toISOString();
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (Number.isFinite(parsed.getTime())) return parsed.toISOString();
  }
  return fallback;
}

export function sanitizePublicLegalConfig(value: unknown): UnknownMap {
  const data = asMap(value);
  const publisher = asMap(data.publisher);
  const operatingMode = limitedString(data.operatingMode, 20) === "commercial"
    ? "commercial"
    : "free_beta";

  return {
    operatingMode,
    legalVersion: limitedString(
      data.legalVersion,
      80,
      operatingMode === "commercial" ? "commercial-v1" : "beta-free-v1",
    ),
    cguVersion: limitedString(
      data.cguVersion,
      80,
      operatingMode === "commercial" ? "cgu-commercial-v1" : "cgu-beta-free-v1",
    ),
    privacyVersion: limitedString(
      data.privacyVersion,
      80,
      operatingMode === "commercial" ? "privacy-commercial-v1" : "privacy-beta-free-v1",
    ),
    effectiveDate: isoDate(data.effectiveDate, BETA_EFFECTIVE_DATE),
    requiresReacceptance: data.requiresReacceptance === true,
    updatedAt: isoDate(data.updatedAt, BETA_EFFECTIVE_DATE),
    publisher: {
      publisherName: limitedString(publisher.publisherName, 160),
      postalAddress: limitedString(publisher.postalAddress, 500),
      phone: limitedString(publisher.phone, 40),
      email: limitedString(publisher.email, 254, "contact@ilipresto.fr"),
      publicationDirector: limitedString(publisher.publicationDirector, 160),
      companyName: limitedString(publisher.companyName, 200),
      legalForm: limitedString(publisher.legalForm, 80),
      siren: limitedString(publisher.siren, 20),
      rcs: limitedString(publisher.rcs, 120),
      shareCapital: limitedString(publisher.shareCapital, 80),
      vatNumber: limitedString(publisher.vatNumber, 40),
      hostingProvider: limitedString(
        publisher.hostingProvider,
        200,
        "Google Ireland Limited (Firebase Hosting)",
      ),
      hostingAddress: limitedString(
        publisher.hostingAddress,
        500,
        "Gordon House, Barrow Street, Dublin 4, Irlande",
      ),
    },
  };
}

export const getPublicLegalConfig = onCall({
  region: PROJECT_REGION,
  enforceAppCheck: false,
  timeoutSeconds: 10,
  memory: "256MiB",
  maxInstances: 20,
}, async () => {
  const snapshot = await db.collection("app_config").doc("legal").get();
  return sanitizePublicLegalConfig(snapshot.data());
});
