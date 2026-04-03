import assert from "node:assert/strict";
import test from "node:test";

import {
  compatTemplateRegistry,
  getCompatDefaultTemplateContent,
  getCompatTemplateMeta,
  listCompatMissingRequiredVariables,
} from "./compat_registry";

test("compat registry exposes modular templates to the worker", () => {
  const meta = getCompatTemplateMeta("tpl_transactional_payment_confirmed_v2");

  assert.ok(meta);
  assert.equal(meta?.channel, "transactionnel");
  assert.equal(meta?.category, "billing");
  assert.ok(compatTemplateRegistry.some((item) => item.template_code === "tpl_transactional_payment_confirmed_v2"));
});

test("compat registry returns modular fallback content", () => {
  const content = getCompatDefaultTemplateContent("tpl_transactional_account_welcome_v2", "fr");

  assert.match(content.html, /brandLogoUrl/);
  assert.match(content.text, /e-livre resto/);
});

test("compat registry validates required variables for modular templates", () => {
  const missing = listCompatMissingRequiredVariables("tpl_transactional_account_deletion_requested_v1", {
    firstName: "Nina",
  });

  assert.deepEqual(missing, ["deletionDate", "cancelDeletionUrl"]);
});