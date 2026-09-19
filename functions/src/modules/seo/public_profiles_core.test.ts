import assert from "node:assert/strict";
import test from "node:test";

import {
  buildPublicProfileProjection,
  extractPublicProfileId,
  isIndexablePublicProfile,
  normalizePublicProfile,
  publicProfileCanonical,
  publicProfileIdForUid,
  renderPublicProfileHtml,
  renderPublicProfilesSitemap,
  sourceProfileIsPublicEligible,
  sourceProfilePublicEligibilityReasons,
} from "./public_profiles_core";

const source = {
  seoPublicProfileConsent: true,
  siretVerified: true,
  establishmentActive: true,
  companyName: "Atelier Soleil",
  activity: "Bricolage et petits travaux",
  description: "Professionnel vérifié proposant des prestations de bricolage, montage de meubles et petits travaux avec une présentation suffisamment détaillée pour informer les visiteurs.",
  serviceCategories: "Bricolage / Travaux",
  interventionZone: "Baie-Mahault et communes voisines",
  city: "Baie-Mahault",
  postalCode: "97122",
  website: "https://example.test/",
  contactPhone: "+590690000000",
  contactEmail: "private@example.test",
  siret: "12345678901234",
  address: "Adresse privée",
};

test("public profile projection requires explicit SEO consent and verified data", () => {
  assert.equal(sourceProfileIsPublicEligible(source), true);
  assert.equal(sourceProfileIsPublicEligible({ ...source, seoPublicProfileConsent: false }), false);
  assert.equal(sourceProfileIsPublicEligible({ ...source, description: "Trop court" }), false);
});

test("public profile eligibility diagnostics are aggregate-safe reason codes", () => {
  assert.deepEqual(sourceProfilePublicEligibilityReasons(source), []);
  assert.deepEqual(
    sourceProfilePublicEligibilityReasons({
      ...source,
      seoPublicProfileConsent: false,
      siretVerified: false,
      description: "Trop court",
      city: "",
    }),
    ["consent_missing", "siret_unverified", "description_too_short", "city_missing"],
  );
});

test("projection contains only SEO-safe public fields", () => {
  const projection = buildPublicProfileProjection("uid-private-123", source);
  assert.match(projection.publicId, /^[a-f0-9]{24}$/);
  assert.equal("contactPhone" in projection, false);
  assert.equal("contactEmail" in projection, false);
  assert.equal("siret" in projection, false);
  assert.equal("address" in projection, false);
});

test("public profile route never exposes the Firebase uid", () => {
  const publicId = publicProfileIdForUid("uid-private-123");
  const canonical = publicProfileCanonical(publicId, source.companyName);
  assert.match(canonical, /\/prestataires\/atelier-soleil\/[a-f0-9]{24}\/$/);
  assert.doesNotMatch(canonical, /uid-private-123/);
  assert.equal(extractPublicProfileId(new URL(canonical).pathname), publicId);
  assert.equal(extractPublicProfileId(`/prestataires/${publicId}/`), publicId);
});

test("public profile HTML emits ProfilePage without private data or JobPosting", () => {
  const publicId = publicProfileIdForUid("uid-private-123");
  const profile = normalizePublicProfile(publicId, {
    ...buildPublicProfileProjection("uid-private-123", source),
    publishedAt: "2026-09-18T12:00:00.000Z",
    updatedAt: "2026-09-18T12:30:00.000Z",
  });
  assert.equal(isIndexablePublicProfile(profile), true);
  const html = renderPublicProfileHtml(profile);
  assert.match(html, /"@type":"ProfilePage"/);
  assert.match(html, /Atelier Soleil/);
  assert.doesNotMatch(html, /private@example\.test/);
  assert.doesNotMatch(html, /690000000/);
  assert.doesNotMatch(html, /12345678901234/);
  assert.doesNotMatch(html, /Adresse privée/);
  assert.doesNotMatch(html, /JobPosting/);
});

test("profile sitemap contains only indexable public profiles", () => {
  const publicId = publicProfileIdForUid("uid-private-123");
  const good = normalizePublicProfile(publicId, {
    ...buildPublicProfileProjection("uid-private-123", source),
    publishedAt: "2026-09-18T12:00:00.000Z",
    updatedAt: "2026-09-18T12:30:00.000Z",
  });
  const weak = { ...good, publicId: publicProfileIdForUid("uid-private-456"), seoEligible: false };
  const sitemap = renderPublicProfilesSitemap([good, weak]);
  assert.match(sitemap, new RegExp(publicId));
  assert.doesNotMatch(sitemap, new RegExp(weak.publicId));
});
