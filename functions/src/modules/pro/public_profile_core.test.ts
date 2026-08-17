import assert from "node:assert/strict";
import test from "node:test";

import {
  PUBLIC_PROFILE_CONSENT_VERSION,
  buildPublicProfessionalProfileProjection,
  canPublishPublicProfessionalProfile,
  hasValidPublicProfileConsent,
  isEligibleForPublicProfessionalProfile,
} from "./public_profile_core";

const verifiedPrivateProfile: Record<string, unknown> = {
  uid: "private-user-id",
  publicProfileEnabled: true,
  siretVerified: true,
  establishmentActive: true,
  proStatus: "verified_siret",
  companyName: "Atelier Exemple",
  city: "Les Abymes",
  nafCode: "43.32A",
  siret: "12345678901234",
  siren: "123456789",
  address: "12 rue confidentielle",
  postalCode: "97139",
  email: "private@example.test",
  phone: "+590690000000",
  verifiedSource: "api_recherche_entreprises",
  stripeCustomerId: "cus_private",
  moderationNotes: "private moderation note",
};

const validServerConsent: Record<string, unknown> = {
  enabled: true,
  version: PUBLIC_PROFILE_CONSENT_VERSION,
  source: "authenticated_user_callable",
};

test("professional profile is private by default", () => {
  const candidate = {
    ...verifiedPrivateProfile,
    publicProfileEnabled: undefined,
  };

  assert.equal(isEligibleForPublicProfessionalProfile(candidate), false);
  assert.equal(buildPublicProfessionalProfileProjection(candidate), null);
});

test("only a verified active professional can opt in", () => {
  assert.equal(isEligibleForPublicProfessionalProfile(verifiedPrivateProfile), true);

  for (const patch of [
    { siretVerified: false },
    { establishmentActive: false },
    { proStatus: "pending" },
    { companyName: "" },
    { city: "" },
  ]) {
    assert.equal(
      isEligibleForPublicProfessionalProfile({ ...verifiedPrivateProfile, ...patch }),
      false,
    );
  }
});

test("server-side consent is mandatory and versioned", () => {
  assert.equal(hasValidPublicProfileConsent(validServerConsent), true);
  assert.equal(canPublishPublicProfessionalProfile(verifiedPrivateProfile, validServerConsent), true);

  for (const consent of [
    undefined,
    { enabled: false, version: PUBLIC_PROFILE_CONSENT_VERSION, source: "authenticated_user_callable" },
    { enabled: true, version: "old-version", source: "authenticated_user_callable" },
    { enabled: true, version: PUBLIC_PROFILE_CONSENT_VERSION, source: "client_write" },
  ]) {
    assert.equal(hasValidPublicProfileConsent(consent), false);
    assert.equal(canPublishPublicProfessionalProfile(verifiedPrivateProfile, consent), false);
  }
});

test("public projection is strictly whitelisted and contains no PII", () => {
  const projection = buildPublicProfessionalProfileProjection(verifiedPrivateProfile);
  assert.deepEqual(projection, {
    companyName: "Atelier Exemple",
    city: "Les Abymes",
    activityCode: "43.32A",
    verifiedProfessional: true,
    visibility: "public",
  });

  const serialized = JSON.stringify(projection);
  for (const privateValue of [
    "private-user-id",
    "12345678901234",
    "123456789",
    "12 rue confidentielle",
    "97139",
    "private@example.test",
    "+590690000000",
    "cus_private",
    "private moderation note",
    "api_recherche_entreprises",
  ]) {
    assert.equal(serialized.includes(privateValue), false);
  }
});

test("opting out removes eligibility immediately", () => {
  const candidate = {
    ...verifiedPrivateProfile,
    publicProfileEnabled: false,
  };
  assert.equal(buildPublicProfessionalProfileProjection(candidate), null);
  assert.equal(canPublishPublicProfessionalProfile(candidate, validServerConsent), false);
});
