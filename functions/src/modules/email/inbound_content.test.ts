import assert from "node:assert/strict";
import test from "node:test";

import {
  emailPreview,
  htmlEmailToPlainText,
  markdownEmailToPlainText,
  plainEmailToDisplayText,
  selectInboundDisplayBody,
} from "./inbound_content";

test("markdownEmailToPlainText supprime les liens techniques Brevo visibles", () => {
  const input = [
    "[baifiddj.r.bh.d.sendibt3.com/tr/op/f1bgg...](https://baifiddj.r.bh.d.sendibt3.com)",
    "",
    "Certification technique Brevo iliprestō.",
  ].join("\n");

  assert.equal(markdownEmailToPlainText(input), "Certification technique Brevo iliprestō.");
});

test("markdownEmailToPlainText conserve le libellé humain d un lien tracké", () => {
  const input = "[Ouvrir iliprestō](https://abc.r.bh.d.sendibt2.com/tr/click/123)";
  assert.equal(markdownEmailToPlainText(input), "Ouvrir iliprestō");
});

test("plainEmailToDisplayText retire une URL de tracking mais conserve une URL métier", () => {
  const input = [
    "Suivi: https://abc.r.bh.d.sendibt3.com/tr/op/123",
    "Site: https://ilipresto.fr",
  ].join("\n");

  assert.equal(
    plainEmailToDisplayText(input),
    ["Suivi:", "Site: https://ilipresto.fr"].join("\n"),
  );
});

test("selectInboundDisplayBody préfère la version texte brute au markdown Brevo", () => {
  const result = selectInboundDisplayBody({
    rawText: "Bonjour depuis la version texte.",
    markdown: "[tracking](https://abc.sendibt3.com/tr/op/1)\nVersion markdown.",
    html: "<p>Version HTML</p>",
  });

  assert.deepEqual(result, {
    text: "Bonjour depuis la version texte.",
    source: "raw_text",
  });
});

test("selectInboundDisplayBody nettoie le markdown existant quand le texte brut manque", () => {
  const result = selectInboundDisplayBody({
    markdown: "[abc.sendibt3.com/tr/op/x](https://abc.sendibt3.com)\n\nMessage utile",
  });

  assert.deepEqual(result, {
    text: "Message utile",
    source: "markdown",
  });
});

test("htmlEmailToPlainText fournit un fallback sûr sans balises ni scripts", () => {
  const html = [
    "<html><head><style>.x{color:red}</style></head>",
    "<body><h1>Bonjour</h1><p>Message &amp; suite</p>",
    "<script>alert('x')</script></body></html>",
  ].join("");

  assert.equal(htmlEmailToPlainText(html), "Bonjour\nMessage & suite");
});

test("emailPreview aplatit les espaces et borne la taille", () => {
  assert.equal(emailPreview("Bonjour\n\n  iliprestō", 12), "Bonjour ilip");
});
