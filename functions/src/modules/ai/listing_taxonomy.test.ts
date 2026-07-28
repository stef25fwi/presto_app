import assert from "node:assert/strict";
import test from "node:test";

import {
  correctAntillesTranscript,
  departmentFromPostalCode,
  findPostalCode,
  LISTING_CATEGORY_VALUES,
  normalizeListingCategory,
} from "./listing_taxonomy";

test("canonical taxonomy normalizes common category aliases", () => {
  assert.equal(normalizeListingCategory("travaux"), "Bricolage / Travaux");
  assert.equal(normalizeListingCategory("AIDE À DOMICILE"), "Aide à domicile");
  assert.equal(normalizeListingCategory("manutention"), "Main-d'œuvre");
  assert.equal(normalizeListingCategory("inconnue"), null);
  assert.equal(new Set(LISTING_CATEGORY_VALUES).size, LISTING_CATEGORY_VALUES.length);
});

test("Antilles city normalization resolves postal codes and departments", () => {
  assert.equal(findPostalCode("Baie Mahault"), "97122");
  assert.equal(findPostalCode("Pointe-à-Pitre"), "97110");
  assert.equal(findPostalCode("Fort de France"), "97200");
  assert.equal(departmentFromPostalCode("97122"), "971");
  assert.equal(departmentFromPostalCode("75001"), "75");
});

test("transcript corrections preserve meaning while fixing local names", () => {
  assert.equal(
    correctAntillesTranscript("je cherche quelqu'un à baie ma haut"),
    "je cherche quelqu'un à Baie-Mahault",
  );
});
