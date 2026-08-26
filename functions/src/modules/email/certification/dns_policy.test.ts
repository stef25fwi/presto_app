import assert from "node:assert/strict";
import test from "node:test";

import {
  assessDkim,
  assessDmarc,
  assessSenderDns,
  assessSpf,
  joinTxtChunks,
  parseDmarcTags,
} from "./dns_policy";

test("joinTxtChunks recolle les fragments TXT sans séparateur", () => {
  assert.equal(joinTxtChunks(["v=spf1 include:", "spf.brevo.com -all"]), "v=spf1 include:spf.brevo.com -all");
});

test("assessSpf valide un SPF Brevo unique et strict", () => {
  const spf = assessSpf([["v=spf1 include:spf.brevo.com -all"], ["google-site-verification=abc"]]);

  assert.equal(spf.ok, true);
  assert.equal(spf.includesProvider, true);
  assert.equal(spf.providerMechanism, "include:spf.brevo.com");
  assert.equal(spf.allQualifier, "-all");
  assert.equal(spf.lookupCount, 1);
});

test("assessSpf accepte l ancien include Sendinblue", () => {
  const spf = assessSpf([["v=spf1 include:spf.sendinblue.com ~all"]]);

  assert.equal(spf.ok, true);
  assert.equal(spf.providerMechanism, "include:spf.sendinblue.com");
});

test("assessSpf rejette deux SPF concurrents", () => {
  const spf = assessSpf([
    ["v=spf1 include:spf.brevo.com -all"],
    ["v=spf1 include:_spf.google.com -all"],
  ]);

  assert.equal(spf.ok, false);
  assert.ok(spf.issues.includes("spf_multiple_records"));
});

test("assessSpf signale l absence de Brevo et un all permissif", () => {
  const spf = assessSpf([["v=spf1 include:_spf.google.com +all"]]);

  assert.equal(spf.ok, false);
  assert.ok(spf.issues.includes("spf_brevo_missing"));
  assert.ok(spf.issues.includes("spf_all_permissive"));
});

test("assessSpf compte les lookups DNS et signale le dépassement", () => {
  const record = `v=spf1 ${Array.from({ length: 11 }, (_, index) => `include:h${index}.example.com`).join(" ")} -all`;
  const spf = assessSpf([[record]]);

  assert.equal(spf.lookupCount, 11);
  assert.ok(spf.issues.includes("spf_lookup_limit_exceeded"));
});

test("assessSpf signale un SPF absent", () => {
  const spf = assessSpf([["google-site-verification=abc"]]);

  assert.equal(spf.ok, false);
  assert.deepEqual(spf.issues, ["spf_missing"]);
});

test("assessSpf signale un enregistrement sans mécanisme all", () => {
  const spf = assessSpf([["v=spf1 include:spf.brevo.com"]]);

  assert.ok(spf.issues.includes("spf_all_missing"));
});

test("parseDmarcTags extrait les paires clé/valeur", () => {
  const tags = parseDmarcTags("v=DMARC1; p=quarantine; rua=mailto:dmarc@ilipresto.fr; pct=50");

  assert.equal(tags.v, "DMARC1");
  assert.equal(tags.p, "quarantine");
  assert.equal(tags.pct, "50");
});

test("assessDmarc valide un enregistrement surveillé", () => {
  const dmarc = assessDmarc(
    [["v=DMARC1; p=none; rua=mailto:dmarc@ilipresto.fr"]],
    "ilipresto.fr",
    { monitoredMailboxes: ["dmarc@ilipresto.fr"] },
  );

  assert.equal(dmarc.ok, true);
  assert.equal(dmarc.policy, "none");
  assert.deepEqual(dmarc.rua, ["mailto:dmarc@ilipresto.fr"]);
  assert.equal(dmarc.warnings.includes("dmarc_rua_external_domain"), false);
});

test("assessDmarc refuse une boîte de rapports non surveillée", () => {
  const dmarc = assessDmarc(
    [["v=DMARC1; p=none; rua=mailto:rapports@exemple-tiers.fr"]],
    "ilipresto.fr",
    { monitoredMailboxes: ["dmarc@ilipresto.fr"] },
  );

  assert.equal(dmarc.ok, false);
  assert.ok(dmarc.issues.includes("dmarc_rua_unmonitored"));
  assert.ok(dmarc.warnings.includes("dmarc_rua_external_domain"));
});

test("assessDmarc accepte un rua mixte tant qu'une boîte surveillée y figure", () => {
  const dmarc = assessDmarc(
    [["v=DMARC1; p=quarantine; rua=mailto:rua@dmarc.brevo.com,mailto:contact@ilipresto.fr"]],
    "ilipresto.fr",
    { monitoredMailboxes: ["contact@ilipresto.fr", "dmarc@ilipresto.fr"] },
  );

  assert.equal(dmarc.ok, true);
  assert.equal(dmarc.issues.includes("dmarc_rua_unmonitored"), false);
});

test("assessDmarc tolère la limite de taille sur une adresse rua", () => {
  const dmarc = assessDmarc(
    [["v=DMARC1; p=reject; rua=mailto:dmarc@ilipresto.fr!10m"]],
    "ilipresto.fr",
    { monitoredMailboxes: ["dmarc@ilipresto.fr"] },
  );

  assert.equal(dmarc.ok, true);
});

test("assessDmarc applique la politique minimale demandée", () => {
  const dmarc = assessDmarc(
    [["v=DMARC1; p=none; rua=mailto:dmarc@ilipresto.fr"]],
    "ilipresto.fr",
    { monitoredMailboxes: ["dmarc@ilipresto.fr"], minimumPolicy: "quarantine" },
  );

  assert.equal(dmarc.ok, false);
  assert.ok(dmarc.issues.includes("dmarc_policy_below_minimum"));
});

test("assessDmarc rejette une syntaxe invalide", () => {
  const dmarc = assessDmarc([["v=DMARC1; p=bloque; pct=150"]], "ilipresto.fr");

  assert.equal(dmarc.ok, false);
  assert.ok(dmarc.issues.includes("dmarc_policy_invalid"));
  assert.ok(dmarc.issues.includes("dmarc_pct_invalid"));
});

test("assessDmarc signale l absence totale d enregistrement", () => {
  const dmarc = assessDmarc([], "ilipresto.fr");

  assert.equal(dmarc.ok, false);
  assert.deepEqual(dmarc.issues, ["dmarc_missing"]);
});

test("assessDkim valide les enregistrements publiés", () => {
  const dkim = assessDkim(
    [
      { host: "mail._domainkey.ilipresto.fr", type: "TXT", value: "k=rsa;p=MIGf", providerStatus: true },
      { host: "brevo._domainkey.ilipresto.fr", type: "TXT", value: "k=rsa;p=AAAB", providerStatus: true },
    ],
    [
      { host: "mail._domainkey.ilipresto.fr.", values: ["k=rsa;p=MIGf"] },
      { host: "brevo._domainkey.ilipresto.fr", values: ["k=rsa;p=AAAB"] },
    ],
  );

  assert.equal(dkim.ok, true);
  assert.equal(dkim.entries.length, 2);
  assert.ok(dkim.entries.every((entry) => entry.published));
});

test("assessDkim détecte un enregistrement manquant ou divergent", () => {
  const dkim = assessDkim(
    [
      { host: "mail._domainkey.ilipresto.fr", type: "TXT", value: "k=rsa;p=MIGf" },
      { host: "brevo._domainkey.ilipresto.fr", type: "TXT", value: "k=rsa;p=AAAB" },
    ],
    [{ host: "mail._domainkey.ilipresto.fr", values: ["k=rsa;p=DIFFERENT"] }],
  );

  assert.equal(dkim.ok, false);
  assert.ok(dkim.issues.includes("dkim_record_mismatch"));
  assert.ok(dkim.issues.includes("dkim_record_missing"));
});

test("assessDkim remonte un statut Brevo encore en attente", () => {
  const dkim = assessDkim(
    [{ host: "mail._domainkey.ilipresto.fr", type: "TXT", value: "k=rsa;p=MIGf", providerStatus: false }],
    [{ host: "mail._domainkey.ilipresto.fr", values: ["k=rsa;p=MIGf"] }],
  );

  assert.equal(dkim.ok, false);
  assert.ok(dkim.issues.includes("dkim_provider_status_pending"));
});

test("assessDkim échoue quand Brevo ne fournit aucune attente DKIM", () => {
  const dkim = assessDkim([], []);

  assert.equal(dkim.ok, false);
  assert.deepEqual(dkim.issues, ["dkim_expectations_missing"]);
});

test("assessSenderDns agrège les trois contrôles avec un préfixe explicite", () => {
  const assessment = assessSenderDns({
    domain: "ilipresto.fr",
    spfTxt: [["v=spf1 include:spf.brevo.com -all"]],
    dmarcTxt: [["v=DMARC1; p=none; rua=mailto:dmarc@ilipresto.fr"]],
    dkimExpectations: [
      { host: "mail._domainkey.ilipresto.fr", type: "TXT", value: "k=rsa;p=MIGf", providerStatus: true },
    ],
    dkimResolutions: [{ host: "mail._domainkey.ilipresto.fr", values: ["k=rsa;p=MIGf"] }],
    dmarcOptions: { monitoredMailboxes: ["dmarc@ilipresto.fr"] },
  });

  assert.equal(assessment.ok, true);
  assert.deepEqual(assessment.issues, []);
});

test("assessSenderDns préfixe les anomalies par leur famille", () => {
  const assessment = assessSenderDns({
    domain: "ilipresto.fr",
    spfTxt: [],
    dmarcTxt: [],
    dkimExpectations: [{ host: "mail._domainkey.ilipresto.fr", type: "TXT", value: "k=rsa;p=MIGf" }],
    dkimResolutions: [],
  });

  assert.equal(assessment.ok, false);
  assert.ok(assessment.issues.includes("spf:spf_missing"));
  assert.ok(assessment.issues.includes("dkim:dkim_record_missing"));
  assert.ok(assessment.issues.includes("dmarc:dmarc_missing"));
});
