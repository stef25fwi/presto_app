import assert from "node:assert/strict";
import test from "node:test";

import { applyFirestoreEmailBranding } from "./branding";

test("applyFirestoreEmailBranding injects logo block into Firestore HTML templates", () => {
  const branded = applyFirestoreEmailBranding(
    "<html><body><p>Bonjour {{firstName}}</p></body></html>",
    "Confirmez votre adresse e-mail",
  );

  assert.match(branded, /data-presto-email-branding/);
  assert.match(branded, /\{\{brandLogoUrl\}\}/);
  assert.match(branded, /Confirmez votre adresse e-mail/);
});

test("applyFirestoreEmailBranding does not duplicate an existing logo block", () => {
  const original = "<html><body><img src=\"{{brandLogoUrl}}\" alt=\"{{brandLogoAlt}}\"><p>Bonjour</p></body></html>";
  const branded = applyFirestoreEmailBranding(original, "Préheader");

  assert.equal(branded, original);
});