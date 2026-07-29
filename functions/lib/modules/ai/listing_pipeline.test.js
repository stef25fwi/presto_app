"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const listing_pipeline_1 = require("./listing_pipeline");
(0, node_test_1.default)("quality gate accepts a clear Google transcript", () => {
    const quality = (0, listing_pipeline_1.evaluateTranscriptQuality)({
        text: "Je recherche une personne pour tondre mon jardin à Baie-Mahault.",
        confidence: 0.88,
        threshold: 0.62,
    });
    strict_1.default.equal(quality.acceptable, true);
    strict_1.default.ok(quality.score >= 0.62);
    strict_1.default.deepEqual(quality.reasons, []);
});
(0, node_test_1.default)("quality gate requests fallback for a short uncertain transcript", () => {
    const quality = (0, listing_pipeline_1.evaluateTranscriptQuality)({
        text: "tonte euh",
        confidence: 0.31,
        threshold: 0.62,
    });
    strict_1.default.equal(quality.acceptable, false);
    strict_1.default.ok(quality.reasons.includes("text_too_short"));
    strict_1.default.ok(quality.reasons.includes("low_confidence"));
});
(0, node_test_1.default)("legacy draft payload keeps Flutter contract and explicit budget", () => {
    const payload = (0, listing_pipeline_1.buildLegacyDraftPayload)({
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
    strict_1.default.equal(payload.titre, "Tonte de jardin");
    strict_1.default.equal(payload.categorie, "Jardinage");
    strict_1.default.deepEqual(payload.budget, {
        type: "fixe",
        min: 50,
        max: 50,
        devise: "EUR",
    });
});
//# sourceMappingURL=listing_pipeline.test.js.map