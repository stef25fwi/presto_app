import assert from "node:assert/strict";
import test from "node:test";

import {
  MAX_REFERENCE_IMAGE_BYTES,
  VideoMakerValidationError,
  normalizeApiKey,
  normalizeAspectRatio,
  normalizeReferenceImage,
  normalizeVideoPrompt,
} from "./videomaker_utils";

test("normalizeVideoPrompt trims a valid prompt", () => {
  assert.equal(normalizeVideoPrompt("  scène tropicale  "), "scène tropicale");
});

test("normalizeVideoPrompt rejects an empty prompt", () => {
  assert.throws(() => normalizeVideoPrompt("  "), VideoMakerValidationError);
});

test("normalizeAspectRatio defaults to portrait and accepts landscape", () => {
  assert.equal(normalizeAspectRatio(undefined), "9:16");
  assert.equal(normalizeAspectRatio("16:9"), "16:9");
});

test("normalizeReferenceImage validates size and mime type", () => {
  const image = normalizeReferenceImage(Buffer.from("image").toString("base64"), "image/png");
  assert.equal(image?.mimeType, "image/png");
  assert.equal(image?.byteLength, 5);

  const tooLarge = Buffer.alloc(MAX_REFERENCE_IMAGE_BYTES + 1).toString("base64");
  assert.throws(
    () => normalizeReferenceImage(tooLarge, "image/jpeg"),
    VideoMakerValidationError,
  );
});

test("normalizeApiKey uses the server secret when the field is empty", () => {
  assert.equal(normalizeApiKey("", "server-key"), "server-key");
});
