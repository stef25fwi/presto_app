#!/usr/bin/env node
/**
 * Certification DNS publique du domaine d'envoi iliprestō.
 *
 * `brevo_production_audit.mjs` ne lit que le statut auto-déclaré par Brevo.
 * Ce script interroge le DNS public : SPF unique et autorisant Brevo, DKIM
 * réellement publiés avec les valeurs attendues, DMARC syntaxiquement valide
 * et pointant vers une boîte surveillée.
 */
import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { Resolver } from "node:dns/promises";

import { assessSenderDns } from "../lib/modules/email/certification/dns_policy.js";

function readArg(name, fallback) {
  const direct = process.argv.find((arg) => arg.startsWith(`${name}=`));
  if (direct) return direct.slice(name.length + 1);
  const idx = process.argv.indexOf(name);
  if (idx >= 0 && process.argv[idx + 1] && !process.argv[idx + 1].startsWith("--")) {
    return process.argv[idx + 1];
  }
  return fallback;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function splitList(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

const domain = readArg("--domain", process.env.BREVO_SENDER_DOMAIN || "ilipresto.fr").toLowerCase();
const output = readArg("--output", process.env.BREVO_SENDER_DNS_OUTPUT || "quality/brevo-sender-dns.json");
const skipDkim = hasFlag("--skip-dkim");
const monitoredMailboxes = splitList(
  process.env.DMARC_MONITORED_MAILBOXES || `dmarc@${domain},contact@${domain}`,
);
const minimumPolicy = (process.env.DMARC_MINIMUM_POLICY || "none").toLowerCase();
const apiKey = String(process.env.BREVO_API_KEY || "").trim();

const resolver = new Resolver();
const customServers = splitList(process.env.DNS_RESOLVERS);
if (customServers.length > 0) resolver.setServers(customServers);

function fqdn(host) {
  const normalized = String(host || "").trim().replace(/\.$/, "").toLowerCase();
  // "@" est la convention de zone DNS pour l'apex du domaine (utilisée par
  // l'API Brevo pour son enregistrement brevo-code) : sans ce cas, elle est
  // concaténée telle quelle et produit un nom de requête invalide.
  if (normalized.length === 0 || normalized === "@") return domain;
  return normalized.endsWith(domain) ? normalized : `${normalized}.${domain}`;
}

async function resolveTxtSafe(name) {
  try {
    return await resolver.resolveTxt(name);
  } catch (error) {
    if (["ENOTFOUND", "ENODATA", "NXDOMAIN"].includes(error?.code)) return [];
    throw error;
  }
}

async function resolveCnameSafe(name) {
  try {
    return await resolver.resolveCname(name);
  } catch (error) {
    if (["ENOTFOUND", "ENODATA", "NXDOMAIN"].includes(error?.code)) return [];
    throw error;
  }
}

/** Récupère chez Brevo les enregistrements DKIM attendus pour ce domaine. */
async function fetchBrevoDkimExpectations() {
  if (!apiKey) return { expectations: [], source: "unavailable" };

  const response = await fetch(
    `https://api.brevo.com/v3/senders/domains/${encodeURIComponent(domain)}`,
    { headers: { accept: "application/json", "api-key": apiKey } },
  );
  // Le domaine peut ne pas encore exister côté Brevo : c'est un échec de
  // certification, pas une panne du script.
  if (response.status === 404) return { expectations: [], source: "domain_absent" };
  if (!response.ok) {
    throw new Error(`Brevo GET /senders/domains/${domain} -> HTTP ${response.status}`);
  }

  const body = await response.json();
  const records = body?.dns_records || {};
  const expectations = Object.entries(records)
    .filter(([key]) => key.toLowerCase().includes("dkim") || key.toLowerCase().includes("brevo_code"))
    .map(([key, record]) => ({
      key,
      host: fqdn(record?.host_name),
      type: String(record?.type || "TXT").toUpperCase(),
      value: String(record?.value || ""),
      providerStatus: record?.status === true,
    }))
    .filter((record) => record.value.length > 0);

  return { expectations, source: "brevo_api", domainConfig: { verified: body?.verified === true, authenticated: body?.authenticated === true } };
}

async function main() {
  const [spfTxt, dmarcTxt] = await Promise.all([
    resolveTxtSafe(domain),
    resolveTxtSafe(`_dmarc.${domain}`),
  ]);

  let expectations = [];
  let dkimSource = "skipped";
  let domainConfig = null;
  if (!skipDkim) {
    const fetched = await fetchBrevoDkimExpectations();
    expectations = fetched.expectations;
    dkimSource = fetched.source;
    domainConfig = fetched.domainConfig ?? null;
  }

  const dkimResolutions = [];
  for (const expectation of expectations) {
    const values = expectation.type === "CNAME"
      ? await resolveCnameSafe(expectation.host)
      : (await resolveTxtSafe(expectation.host)).map((chunks) => chunks.join(""));
    dkimResolutions.push({ host: expectation.host, values });
  }

  const assessment = assessSenderDns({
    domain,
    spfTxt,
    dmarcTxt,
    dkimExpectations: expectations,
    dkimResolutions,
    dmarcOptions: { monitoredMailboxes, minimumPolicy },
  });

  // Sans clé API, DKIM n'est pas vérifiable : ne jamais présenter le résultat
  // partiel comme une certification complète, ni faire passer l'absence
  // d'attentes DKIM pour une anomalie DNS.
  const dkimCertified = !skipDkim && dkimSource === "brevo_api" && assessment.dkim.ok;
  const issues = skipDkim
    ? assessment.issues.filter((issue) => !issue.startsWith("dkim:"))
    : assessment.issues;
  const ok = assessment.spf.ok && assessment.dmarc.ok && (skipDkim ? true : dkimCertified);

  const report = {
    generatedAt: new Date().toISOString(),
    domain,
    resolvers: resolver.getServers(),
    monitoredMailboxes,
    minimumPolicy,
    dkimSource,
    dkimCertified,
    certified: ok && !skipDkim,
    partial: skipDkim,
    domainConfig,
    spf: assessment.spf,
    dkim: assessment.dkim,
    dmarc: assessment.dmarc,
    issues,
    warnings: assessment.warnings,
  };

  await mkdir(dirname(output), { recursive: true });
  await writeFile(output, `${JSON.stringify(report, null, 2)}\n`, "utf8");

  console.log(`SPF   ${assessment.spf.ok ? "PASS" : "FAIL"} ${assessment.spf.record || "(absent)"}`);
  console.log(`DKIM  ${skipDkim ? "SKIP" : dkimCertified ? "PASS" : "FAIL"} (${assessment.dkim.entries.length} enregistrement(s), source ${dkimSource})`);
  for (const entry of assessment.dkim.entries) {
    console.log(`  - ${entry.published ? "ok" : "ko"} ${entry.host}${entry.issues.length > 0 ? ` [${entry.issues.join(", ")}]` : ""}`);
  }
  console.log(`DMARC ${assessment.dmarc.ok ? "PASS" : "FAIL"} ${assessment.dmarc.record || "(absent)"}`);
  for (const warning of report.warnings) console.log(`WARN  ${warning}`);
  for (const issue of report.issues) console.error(`ISSUE ${issue}`);

  console.log(`BREVO_SENDER_DNS_RESULT=${JSON.stringify({
    ok: report.certified,
    domain,
    partial: report.partial,
    spf: assessment.spf.ok,
    dkim: dkimCertified,
    dmarc: assessment.dmarc.ok,
    policy: assessment.dmarc.policy,
    issues,
  })}`);
  console.log(`Report: ${output}`);

  if (!ok) process.exit(2);
  if (skipDkim) {
    console.warn("DKIM non contrôlé (--skip-dkim) : ce run ne certifie pas le domaine.");
  }
}

main().catch((error) => {
  console.error("Contrôle DNS du domaine d envoi en échec:", error?.message || String(error));
  process.exit(1);
});
