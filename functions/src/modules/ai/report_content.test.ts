import assert from "node:assert/strict";
import test from "node:test";

import { validateAiContentReportPayload } from "./report_content";

test("valide un signalement IA sans stocker le résultat généré", () => {
  assert.deepEqual(
    validateAiContentReportPayload({
      source: "publish_text",
      reasonCode: "offensive",
      details: "Résultat à revoir",
      generatedContent: "ne doit pas être persisté",
    }),
    {
      source: "publish_text",
      reasonCode: "offensive",
      details: "Résultat à revoir",
    },
  );
});

test("refuse une source ou un motif hors contrat", () => {
  assert.throws(
    () => validateAiContentReportPayload({
      source: "unknown",
      reasonCode: "offensive",
    }),
    /valid AI content source/,
  );
  assert.throws(
    () => validateAiContentReportPayload({
      source: "publish_voice",
      reasonCode: "unknown",
    }),
    /valid AI content report reason/,
  );
});
