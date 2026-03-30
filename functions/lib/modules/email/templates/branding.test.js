"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const branding_1 = require("./branding");
(0, node_test_1.default)("applyFirestoreEmailBranding injects logo block into Firestore HTML templates", () => {
    const branded = (0, branding_1.applyFirestoreEmailBranding)("<html><body><p>Bonjour {{firstName}}</p></body></html>", "Confirmez votre adresse e-mail");
    strict_1.default.match(branded, /data-presto-email-branding/);
    strict_1.default.match(branded, /\{\{brandLogoUrl\}\}/);
    strict_1.default.match(branded, /Confirmez votre adresse e-mail/);
});
(0, node_test_1.default)("applyFirestoreEmailBranding does not duplicate an existing logo block", () => {
    const original = "<html><body><img src=\"{{brandLogoUrl}}\" alt=\"{{brandLogoAlt}}\"><p>Bonjour</p></body></html>";
    const branded = (0, branding_1.applyFirestoreEmailBranding)(original, "Préheader");
    strict_1.default.equal(branded, original);
});
//# sourceMappingURL=branding.test.js.map