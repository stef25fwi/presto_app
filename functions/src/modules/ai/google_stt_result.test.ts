import assert from "node:assert/strict";
import test from "node:test";
import { summarizeGoogleSttResults } from "./google_stt_result";

test("dictation keeps city and budget from later segments without alternate readings", () => {
  const result = summarizeGoogleSttResults([
    { alternatives: [{ transcript: " Je cherche un peintre. ", confidence: 0.9 }, { transcript: "Une autre lecture" }] },
    { alternatives: [{ transcript: "À Baie-Mahault demain.", confidence: 0.7 }] },
    { alternatives: [{ transcript: "Budget 120 euros.", confidence: 0 }] },
  ]);
  assert.equal(result.text, "Je cherche un peintre. À Baie-Mahault demain. Budget 120 euros.");
  assert.equal(result.googleConfidence, 0.8);
});

test("empty first segment does not hide speech recognized later", () => {
  assert.deepEqual(summarizeGoogleSttResults([
    { alternatives: [] },
    { alternatives: [{ transcript: "  " }] },
    { alternatives: [{ transcript: "Bonjour", confidence: NaN }] },
  ]), { text: "Bonjour", googleConfidence: null });
});

test("no recognized speech stays empty so provider fallback can run", () => {
  for (const results of [undefined, null, [], [{ alternatives: [{ transcript: " " }] }]]) {
    assert.deepEqual(summarizeGoogleSttResults(results), { text: "", googleConfidence: null });
  }
});
