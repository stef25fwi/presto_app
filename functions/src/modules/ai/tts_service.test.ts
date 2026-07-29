import assert from "node:assert/strict";
import test from "node:test";

import {
  buildTtsTextHash,
  resolveTtsConfig,
} from "./tts_service";

test("TTS cache hash includes model voice format and text", () => {
  const first = buildTtsTextHash("Bonjour", {
    model: "tts-1",
    voice: "alloy",
    responseFormat: "mp3",
  });
  const same = buildTtsTextHash("Bonjour", {
    model: "tts-1",
    voice: "alloy",
    responseFormat: "mp3",
  });
  const differentVoice = buildTtsTextHash("Bonjour", {
    model: "tts-1",
    voice: "nova",
    responseFormat: "mp3",
  });

  assert.equal(first, same);
  assert.notEqual(first, differentVoice);
});

test("resolveTtsConfig uses explicit voice and stable defaults", () => {
  const config = resolveTtsConfig("nova");
  assert.equal(config.voice, "nova");
  assert.equal(config.responseFormat, "mp3");
  assert.ok(config.model.length > 0);
});
