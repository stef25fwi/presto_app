import assert from "node:assert/strict";
import test from "node:test";

import { sanitizePublicLegalConfig } from "./public_legal_config";

test("filtre les champs publics et conserve la bêta par défaut", () => {
  const result = sanitizePublicLegalConfig({
    operatingMode: "unexpected",
    internalSecret: "hidden",
    publisher: {
      publisherName: "Exploitant Test",
      email: "contact@example.fr",
      adminUid: "secret-admin-id",
    },
  });

  assert.equal(result.operatingMode, "free_beta");
  assert.equal(result.legalVersion, "beta-free-v1");
  assert.equal("internalSecret" in result, false);

  const publisher = result.publisher as Record<string, unknown>;
  assert.equal(publisher.publisherName, "Exploitant Test");
  assert.equal(publisher.email, "contact@example.fr");
  assert.equal("adminUid" in publisher, false);
});

test("retourne les versions commerciales actives sans données internes", () => {
  const result = sanitizePublicLegalConfig({
    operatingMode: "commercial",
    legalVersion: "commercial-v2",
    cguVersion: "cgu-commercial-v2",
    privacyVersion: "privacy-commercial-v2",
    requiresReacceptance: true,
    publisher: {
      publisherName: "Société Test",
      postalAddress: "1 rue de Test",
      phone: "0590000000",
      email: "legal@example.fr",
      publicationDirector: "Direction Test",
      companyName: "ILIPRESTO SASU",
      legalForm: "SASU",
      siren: "123456789",
    },
  });

  assert.equal(result.operatingMode, "commercial");
  assert.equal(result.legalVersion, "commercial-v2");
  assert.equal(result.requiresReacceptance, true);
});
