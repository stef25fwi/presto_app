"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const callables_1 = require("./callables");
(0, node_test_1.default)("buildLegacyDraftPayload preserves the Flutter publishing contract", () => {
    const payload = (0, callables_1.buildLegacyDraftPayload)({
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
        taxonomyVersion: "ilipresto-listing-taxonomy-v1",
    });
    strict_1.default.equal(payload.title, "Tonte de jardin");
    strict_1.default.equal(payload.titre, "Tonte de jardin");
    strict_1.default.equal(payload.description_courte, "Je recherche une personne pour tondre mon jardin.");
    strict_1.default.equal(payload.categorie, "Jardinage");
    strict_1.default.equal(payload.sous_categorie, "Tonte de pelouse");
    strict_1.default.equal(payload.ville, "Baie-Mahault");
    strict_1.default.equal(payload.postalCode, "97122");
    strict_1.default.deepEqual(payload.details, ["Pelouse devant la maison"]);
    strict_1.default.deepEqual(payload.questions_a_poser, ["Quelle est la surface ?"]);
    strict_1.default.deepEqual(payload.budget, {
        type: null,
        min: null,
        max: null,
        devise: "EUR",
    });
    strict_1.default.equal(payload.taxonomyVersion, "ilipresto-listing-taxonomy-v1");
});
(0, node_test_1.default)("buildLegacyDraftPayload keeps category fallback compatible", () => {
    const payload = (0, callables_1.buildLegacyDraftPayload)({
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
        taxonomyVersion: "ilipresto-listing-taxonomy-v1",
    });
    strict_1.default.equal(payload.category, "Autre");
    strict_1.default.equal(payload.categorie, null);
    strict_1.default.equal(payload.city, "");
    strict_1.default.equal(payload.ville, "");
});
//# sourceMappingURL=callables.test.js.map