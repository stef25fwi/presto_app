import assert from "node:assert/strict";
import test from "node:test";

import { buildLegacyDraftPayload } from "./callables";

test("buildLegacyDraftPayload preserves the Flutter publishing contract", () => {
  const payload = buildLegacyDraftPayload({
    title: "Tonte de jardin",
    description: "Je recherche une personne pour tondre mon jardin.",
    category: "Jardinage",
    subcategory: "Tonte de pelouse",
    city: "Baie-Mahault",
    postalCode: "97122",
    department: "971",
    price: null,
    currency: "EUR",
    listingType: null,
    urgency: null,
    contactPreference: null,
    keywords: ["tonte", "jardin"],
    details: ["Pelouse devant la maison"],
    missingFields: [],
    questionsToAsk: ["Quelle est la surface ?"],
    confidenceScore: 0.92,
  });

  assert.equal(payload.title, "Tonte de jardin");
  assert.equal(payload.titre, "Tonte de jardin");
  assert.equal(payload.description_courte, "Je recherche une personne pour tondre mon jardin.");
  assert.equal(payload.categorie, "Jardinage");
  assert.equal(payload.sous_categorie, "Tonte de pelouse");
  assert.equal(payload.ville, "Baie-Mahault");
  assert.equal(payload.postalCode, "97122");
  assert.deepEqual(payload.details, ["Pelouse devant la maison"]);
  assert.deepEqual(payload.questions_a_poser, ["Quelle est la surface ?"]);
  assert.deepEqual(payload.budget, {
    type: null,
    min: null,
    max: null,
    devise: "EUR",
  });
});

test("buildLegacyDraftPayload keeps category fallback compatible", () => {
  const payload = buildLegacyDraftPayload({
    title: "Besoin ponctuel",
    description: "Je recherche une aide ponctuelle.",
    category: null,
    subcategory: null,
    city: null,
    postalCode: null,
    department: null,
    price: null,
    currency: "EUR",
    listingType: null,
    urgency: null,
    contactPreference: null,
    keywords: [],
    details: [],
    missingFields: ["category", "city", "postalCode"],
    questionsToAsk: [],
    confidenceScore: 0.4,
  });

  assert.equal(payload.category, "Autre");
  assert.equal(payload.categorie, null);
  assert.equal(payload.city, "");
  assert.equal(payload.ville, "");
});
