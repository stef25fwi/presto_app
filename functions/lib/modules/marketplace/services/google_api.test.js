"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const google_api_1 = require("./google_api");
(0, node_test_1.default)("accepte les hôtes Google réellement appelés", () => {
    strict_1.default.equal((0, google_api_1.assertAllowedGoogleApiUrl)("https://vision.googleapis.com/v1/images:annotate").hostname, "vision.googleapis.com");
    strict_1.default.equal((0, google_api_1.assertAllowedGoogleApiUrl)("https://recaptchaenterprise.googleapis.com/v1/projects/presto-app-74abe/assessments").hostname, "recaptchaenterprise.googleapis.com");
});
(0, node_test_1.default)("refuse un hôte tiers", () => {
    strict_1.default.throws(() => (0, google_api_1.assertAllowedGoogleApiUrl)("https://attaquant.example.com/collect"), /Hôte Google API non autorisé : attaquant\.example\.com/);
});
(0, node_test_1.default)("refuse un sous-domaine qui imite un hôte autorisé", () => {
    strict_1.default.throws(() => (0, google_api_1.assertAllowedGoogleApiUrl)("https://vision.googleapis.com.attaquant.example/v1"), /Hôte Google API non autorisé/);
});
(0, node_test_1.default)("refuse un hôte Google non explicitement autorisé", () => {
    strict_1.default.throws(() => (0, google_api_1.assertAllowedGoogleApiUrl)("https://storage.googleapis.com/bucket/objet"), /Hôte Google API non autorisé : storage\.googleapis\.com/);
});
(0, node_test_1.default)("refuse une URL non chiffrée", () => {
    strict_1.default.throws(() => (0, google_api_1.assertAllowedGoogleApiUrl)("http://vision.googleapis.com/v1/images:annotate"), /Google API URL non chiffrée/);
});
(0, node_test_1.default)("refuse une URL illisible", () => {
    strict_1.default.throws(() => (0, google_api_1.assertAllowedGoogleApiUrl)("pas-une-url"), /Google API URL invalide/);
});
(0, node_test_1.default)("refuse une tentative d échappement par identifiants d URL", () => {
    strict_1.default.throws(() => (0, google_api_1.assertAllowedGoogleApiUrl)("https://vision.googleapis.com@attaquant.example/v1/images:annotate"), /Hôte Google API non autorisé : attaquant\.example/);
});
//# sourceMappingURL=google_api.test.js.map