import assert from "node:assert/strict";
import test from "node:test";

import {
  buildLegacyDraftPayload,
  evaluateTranscriptQuality,
} from "./listing_pipeline";

test("quality gate accepts a clear Google transcript", () => {
  const quality = evaluateTranscriptQuality({
    text: "Je recherche une personne pour tondre mon jardin à Baie-Mahault.",
    confidence: 0.88,
    threshold: 0.62,
  });
  assert.equal(quality.acceptable, true);
  assert.ok(quality.score >= 0.62);
  assert.deepEqual(quality.reasons, []);
});

test("quality gate requests fallback for a short uncertain transcript", () => {
  const quality = evaluateTranscriptQuality({
    text: "tonte euh",
    confidence: 0.31,
    threshold: 0.62,
  });
  assert.equal(quality.acceptable, false);
  assert.ok(quality.reasons.includes("text_too_short"));
  assert.ok(quality.reasons.includes("low_confidence"));
});

test("legacy draft payload keeps Flutter contract and explicit budget", () => {
  const payload = buildLegacyDraftPayload({
    title: "Tonte de jardin",
    description: "Je recherche une personne pour tondre mon jardin.",
    category: "Jardinage",
    subcategory: "Tonte de pelouse",
    city: "Baie-Mahault",
    postalCode: "97122",
    department: "971",
    price: 50,
    currency: "EUR",
    listingType: null,
    urgency: null,
    contactPreference: null,
    keywords: ["tonte"],
    details: [],
    missingFields: [],
    questionsToAsk: [],
    confidenceScore: 0.9,
    taxonomyVersion: "ilipresto-listing-taxonomy-v1",
  });
  assert.equal(payload.titre, "Tonte de jardin");
  assert.equal(payload.categorie, "Jardinage");
  assert.deepEqual(payload.budget, {
    type: "fixe",
    min: 50,
    max: 50,
    devise: "EUR",
  });
});
