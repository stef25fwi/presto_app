import assert from "node:assert/strict";
import test from "node:test";

import {
  extractPublicListingId,
  isSeoEligiblePublicListing,
  normalizePublicListingProjection,
  publicListingCanonical,
  renderMissingPublicListingHtml,
  renderPublicListingHtml,
  renderPublicListingsSitemap,
} from "./public_marketplace_core";

const publicListing = normalizePublicListingProjection("listing_123456", {
  status: "active",
  visibility: "public",
  title: "Aide pour monter un meuble",
  description: "Je recherche une personne disponible pour m’aider à monter une armoire et fixer deux étagères dans mon logement. Les outils de base sont disponibles sur place.",
  category: "Bricolage / Travaux",
  categoryId: "bricolage",
  city: "Les Abymes",
  postalCode: "97139",
  publishedAt: "2026-08-09T10:00:00.000Z",
  phone: "+590690000000",
  email: "private@example.test",
  ownerId: "private-owner-id",
});

test("public listing projection keeps only SEO-safe fields", () => {
  assert.equal(publicListing.id, "listing_123456");
  assert.equal(publicListing.status, "active");
  assert.equal(publicListing.visibility, "public");
  assert.equal("phone" in publicListing, false);
  assert.equal("email" in publicListing, false);
  assert.equal("ownerId" in publicListing, false);
  assert.equal(isSeoEligiblePublicListing(publicListing), true);
});

test("public listing renderer emits canonical SEO HTML without private data or JobPosting", () => {
  const html = renderPublicListingHtml(publicListing);
  assert.match(html, /<meta name="robots" content="index,follow/);
  assert.match(html, /<link rel="canonical" href="https:\/\/ilipresto\.fr\/annonces\/listing_123456\/">/);
  assert.match(html, /Aide pour monter un meuble/);
  assert.match(html, /Les Abymes/);
  assert.match(html, /0 % de commission/);
  assert.match(html, /ne collecte ni ne gère les paiements entre utilisateurs/);
  assert.match(html, /convenez directement des conditions de la mission/);
  assert.doesNotMatch(html, /JobPosting/);
  assert.doesNotMatch(html, /private@example\.test/);
  assert.doesNotMatch(html, /690000000/);
  assert.doesNotMatch(html, /private-owner-id/);
});

test("weak or private listings stay outside the SEO sitemap", () => {
  const privateListing = normalizePublicListingProjection("listing_abcdef", {
    status: "draft",
    visibility: "private",
    title: "Annonce privée suffisamment longue",
    description: publicListing.description,
    category: "Bricolage",
    city: "Les Abymes",
  });
  const weakListing = normalizePublicListingProjection("listing_ghijkl", {
    status: "active",
    visibility: "public",
    title: "Trop court",
    description: "Description courte",
    category: "Bricolage",
    city: "Les Abymes",
  });

  const sitemap = renderPublicListingsSitemap([
    publicListing,
    privateListing,
    weakListing,
  ]);
  assert.match(sitemap, /https:\/\/ilipresto\.fr\/annonces\/listing_123456\//);
  assert.doesNotMatch(sitemap, /listing_abcdef/);
  assert.doesNotMatch(sitemap, /listing_ghijkl/);
});

test("listing route parser accepts only stable safe identifiers", () => {
  assert.equal(extractPublicListingId("/annonces/listing_123456/"), "listing_123456");
  assert.equal(extractPublicListingId("/annonces/listing_123456"), "listing_123456");
  assert.equal(extractPublicListingId("/annonces/a/b/"), null);
  assert.equal(extractPublicListingId("/annonces/%2Fprivate/"), null);
  assert.equal(publicListingCanonical("listing_123456"), "https://ilipresto.fr/annonces/listing_123456/");
});

test("missing listing page is explicitly noindex", () => {
  const html = renderMissingPublicListingHtml();
  assert.match(html, /noindex,follow/);
  assert.match(html, /Annonce indisponible/);
});
