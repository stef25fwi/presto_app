"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const requiredLegacyExports = [
    "placesAutocomplete",
    "placesDetails",
    "generateOfferDraft",
    "openAiExtractListingFields",
    "openAiTranscribeListingAudio",
    "openAiExtractListingFieldsFromAudio",
    "adminGetAccessStatus",
    "getMyAdminAccessStatus",
    "adminGetUserStats",
    "getUserPresenceStatus",
    "microIaProcessAudio",
    "adminGetMicroIaConfig",
    "adminSetMicroIaConfig",
];
const requiredTypescriptOnlyExports = [
    "microIaProcessAudioV2",
    "adminGetAiMetrics",
    "purgeExpiredAiAudio",
    "purgeExpiredAiOperationalData",
];
(0, node_test_1.default)("legacy root entrypoint still exposes publish and micro ia callables", () => {
    const legacyIndex = require("../../index.js");
    for (const exportName of requiredLegacyExports) {
        strict_1.default.ok(legacyIndex[exportName], `missing legacy export: ${exportName}`);
    }
});
(0, node_test_1.default)("typescript entrypoint keeps legacy exports and adds progressive AI controls", () => {
    const compiledIndex = require("../index.js");
    for (const exportName of [
        ...requiredLegacyExports,
        ...requiredTypescriptOnlyExports,
    ]) {
        strict_1.default.ok(compiledIndex[exportName], `missing ts export: ${exportName}`);
    }
});
//# sourceMappingURL=callables_compat.test.js.map