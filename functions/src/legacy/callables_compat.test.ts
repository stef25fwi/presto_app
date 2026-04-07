import assert from "node:assert/strict";
import test from "node:test";

const requiredExports = [
  "placesAutocomplete",
  "placesDetails",
  "generateOfferDraft",
  "openAiExtractListingFields",
  "openAiTranscribeListingAudio",
  "openAiExtractListingFieldsFromAudio",
  "adminGetUserStats",
  "getUserPresenceStatus",
  "microIaProcessAudio",
  "adminGetMicroIaConfig",
  "adminSetMicroIaConfig",
] as const;

test("legacy root entrypoint still exposes publish and micro ia callables", () => {
  const legacyIndex = require("../../index.js") as Record<string, unknown>;

  for (const exportName of requiredExports) {
    assert.ok(legacyIndex[exportName], `missing legacy export: ${exportName}`);
  }
});

test("typescript entrypoint mirrors legacy publish and micro ia callables", () => {
  const compiledIndex = require("../index.js") as Record<string, unknown>;

  for (const exportName of requiredExports) {
    assert.ok(compiledIndex[exportName], `missing ts export: ${exportName}`);
  }
});