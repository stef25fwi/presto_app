"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const requiredExports = [
    "placesAutocomplete",
    "placesDetails",
    "generateOfferDraft",
    "openAiExtractListingFields",
    "openAiTranscribeListingAudio",
    "openAiExtractListingFieldsFromAudio",
    "adminGetAccessStatus",
    "adminGetUserStats",
    "getUserPresenceStatus",
    "microIaProcessAudio",
    "adminGetMicroIaConfig",
    "adminSetMicroIaConfig",
];
(0, node_test_1.default)("legacy root entrypoint still exposes publish and micro ia callables", () => {
    const legacyIndex = require("../../index.js");
    for (const exportName of requiredExports) {
        strict_1.default.ok(legacyIndex[exportName], `missing legacy export: ${exportName}`);
    }
});
(0, node_test_1.default)("typescript entrypoint mirrors legacy publish and micro ia callables", () => {
    const compiledIndex = require("../index.js");
    for (const exportName of requiredExports) {
        strict_1.default.ok(compiledIndex[exportName], `missing ts export: ${exportName}`);
    }
});
//# sourceMappingURL=callables_compat.test.js.map