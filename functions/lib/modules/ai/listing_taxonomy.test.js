"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const listing_taxonomy_1 = require("./listing_taxonomy");
(0, node_test_1.default)("canonical taxonomy normalizes common category aliases", () => {
    strict_1.default.equal((0, listing_taxonomy_1.normalizeListingCategory)("travaux"), "Bricolage / Travaux");
    strict_1.default.equal((0, listing_taxonomy_1.normalizeListingCategory)("AIDE À DOMICILE"), "Aide à domicile");
    strict_1.default.equal((0, listing_taxonomy_1.normalizeListingCategory)("manutention"), "Main-d'œuvre");
    strict_1.default.equal((0, listing_taxonomy_1.normalizeListingCategory)("inconnue"), null);
    strict_1.default.equal(new Set(listing_taxonomy_1.LISTING_CATEGORY_VALUES).size, listing_taxonomy_1.LISTING_CATEGORY_VALUES.length);
});
(0, node_test_1.default)("Antilles city normalization resolves postal codes and departments", () => {
    strict_1.default.equal((0, listing_taxonomy_1.findPostalCode)("Baie Mahault"), "97122");
    strict_1.default.equal((0, listing_taxonomy_1.findPostalCode)("Pointe-à-Pitre"), "97110");
    strict_1.default.equal((0, listing_taxonomy_1.findPostalCode)("Fort de France"), "97200");
    strict_1.default.equal((0, listing_taxonomy_1.departmentFromPostalCode)("97122"), "971");
    strict_1.default.equal((0, listing_taxonomy_1.departmentFromPostalCode)("75001"), "75");
});
(0, node_test_1.default)("transcript corrections preserve meaning while fixing local names", () => {
    strict_1.default.equal((0, listing_taxonomy_1.correctAntillesTranscript)("je cherche quelqu'un à baie ma haut"), "je cherche quelqu'un à Baie-Mahault");
});
//# sourceMappingURL=listing_taxonomy.test.js.map