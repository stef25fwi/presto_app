import assert from "node:assert/strict";
import test from "node:test";

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
] as const;

const requiredTypescriptOnlyExports = [
  "microIaProcessAudioV2",
  "adminGetAiMetrics",
  "purgeExpiredAiAudio",
  "purgeExpiredAiOperationalData",
] as const;

test("legacy root entrypoint still exposes publish and micro ia callables", () => {
  const legacyIndex = require("../../index.js") as Record<string, unknown>;
  for (const exportName of requiredLegacyExports) {
    assert.ok(legacyIndex[exportName], `missing legacy export: ${exportName}`);
  }
});

test("typescript entrypoint keeps legacy exports and adds progressive AI controls", () => {
  const compiledIndex = require("../index.js") as Record<string, unknown>;
  for (const exportName of [
    ...requiredLegacyExports,
    ...requiredTypescriptOnlyExports,
  ]) {
    assert.ok(compiledIndex[exportName], `missing ts export: ${exportName}`);
  }
});
