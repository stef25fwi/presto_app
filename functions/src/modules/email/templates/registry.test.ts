import assert from "node:assert/strict";
import test from "node:test";
import { templateRegistry, getDefaultTemplateContent, listMissingRequiredVariables } from "./registry";

test("default fallback content exists for every registered template", () => {
  for (const template of templateRegistry) {
    const content = getDefaultTemplateContent(template.template_code, "fr");
    assert.ok(content.html.includes("PRESTO"), template.template_code);
    assert.ok(content.text.includes("PRESTO"), template.template_code);
  }
});

test("required variable validation reports missing variables", () => {
  const missing = listMissingRequiredVariables("tpl_transactional_support_reply_v1", {
    firstName: "Nina",
    ticketNumber: "SUP-42",
  });

  assert.deepEqual(missing, ["replyUrl"]);
});

test("required variable validation ignores populated variables", () => {
  const missing = listMissingRequiredVariables("tpl_product_saved_search_match_found_v1", {
    searchName: "Plombier",
    matchCount: 3,
    resultsUrl: "https://presto.app/searches/1",
  });

  assert.deepEqual(missing, []);
});