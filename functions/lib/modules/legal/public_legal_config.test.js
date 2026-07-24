"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const public_legal_config_1 = require("./public_legal_config");
(0, node_test_1.default)("filtre les champs publics et conserve la bêta par défaut", () => {
    const result = (0, public_legal_config_1.sanitizePublicLegalConfig)({
        operatingMode: "unexpected",
        internalSecret: "hidden",
        publisher: {
            publisherName: "Exploitant Test",
            email: "contact@example.fr",
            adminUid: "secret-admin-id",
        },
    });
    strict_1.default.equal(result.operatingMode, "free_beta");
    strict_1.default.equal(result.legalVersion, "beta-free-v1");
    strict_1.default.equal("internalSecret" in result, false);
    const publisher = result.publisher;
    strict_1.default.equal(publisher.publisherName, "Exploitant Test");
    strict_1.default.equal(publisher.email, "contact@example.fr");
    strict_1.default.equal("adminUid" in publisher, false);
});
(0, node_test_1.default)("retourne les versions commerciales actives sans données internes", () => {
    const result = (0, public_legal_config_1.sanitizePublicLegalConfig)({
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
    strict_1.default.equal(result.operatingMode, "commercial");
    strict_1.default.equal(result.legalVersion, "commercial-v2");
    strict_1.default.equal(result.requiresReacceptance, true);
});
//# sourceMappingURL=public_legal_config.test.js.map