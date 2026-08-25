#!/usr/bin/env node
/**
 * Rapport de délivrabilité Brevo et application des seuils internes.
 *
 * Les seuils viennent de `modules/email/certification/deliverability`, partagés
 * avec l'alerting runtime : un seuil ne peut pas diverger entre la CI et la
 * production.
 */
import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

import {
  DEFAULT_DELIVERABILITY_THRESHOLDS,
  describeViolation,
  evaluateDeliverability,
} from "../lib/modules/email/certification/deliverability.js";

function readArg(name, fallback) {
  const direct = process.argv.find((arg) => arg.startsWith(`${name}=`));
  if (direct) return direct.slice(name.length + 1);
  const idx = process.argv.indexOf(name);
  if (idx >= 0 && process.argv[idx + 1] && !process.argv[idx + 1].startsWith("--")) {
    return process.argv[idx + 1];
  }
  return fallback;
}

function numberFromEnv(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") return fallback;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) throw new Error(`${name} doit être un nombre`);
  return parsed;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

const apiKey = String(process.env.BREVO_API_KEY || "").trim();
if (!apiKey) throw new Error("BREVO_API_KEY is required");

const days = Number(readArg("--days", process.env.BREVO_DELIVERABILITY_DAYS || "30"));
if (!Number.isInteger(days) || days < 1 || days > 365) {
  throw new Error("--days doit être un entier entre 1 et 365");
}
const output = readArg("--output", "quality/brevo-deliverability.json");
const tag = readArg("--tag", process.env.BREVO_DELIVERABILITY_TAG || "");

const thresholds = {
  minSample: numberFromEnv("BREVO_MIN_SAMPLE", DEFAULT_DELIVERABILITY_THRESHOLDS.minSample),
  minDeliveryRate: numberFromEnv("BREVO_MIN_DELIVERY_RATE", DEFAULT_DELIVERABILITY_THRESHOLDS.minDeliveryRate),
  maxHardBounceRate: numberFromEnv("BREVO_MAX_HARD_BOUNCE_RATE", DEFAULT_DELIVERABILITY_THRESHOLDS.maxHardBounceRate),
  maxSoftBounceRate: numberFromEnv("BREVO_MAX_SOFT_BOUNCE_RATE", DEFAULT_DELIVERABILITY_THRESHOLDS.maxSoftBounceRate),
  maxBounceRate: numberFromEnv("BREVO_MAX_BOUNCE_RATE", DEFAULT_DELIVERABILITY_THRESHOLDS.maxBounceRate),
  maxBlockedRate: numberFromEnv("BREVO_MAX_BLOCKED_RATE", DEFAULT_DELIVERABILITY_THRESHOLDS.maxBlockedRate),
  maxComplaintRate: numberFromEnv("BREVO_MAX_COMPLAINT_RATE", DEFAULT_DELIVERABILITY_THRESHOLDS.maxComplaintRate),
  maxInvalidRate: numberFromEnv("BREVO_MAX_INVALID_RATE", DEFAULT_DELIVERABILITY_THRESHOLDS.maxInvalidRate),
  maxDeferredRate: numberFromEnv("BREVO_MAX_DEFERRED_RATE", DEFAULT_DELIVERABILITY_THRESHOLDS.maxDeferredRate),
};

const endDate = new Date();
const startDate = new Date(endDate.getTime() - (days - 1) * 24 * 60 * 60 * 1000);

const params = new URLSearchParams({
  startDate: isoDate(startDate),
  endDate: isoDate(endDate),
});
if (tag) params.set("tag", tag);

const response = await fetch(`https://api.brevo.com/v3/smtp/statistics/aggregatedReport?${params}`, {
  headers: { accept: "application/json", "api-key": apiKey },
});
if (!response.ok) {
  const body = await response.text();
  throw new Error(`Brevo GET /smtp/statistics/aggregatedReport -> HTTP ${response.status} ${body.slice(0, 300)}`);
}

const raw = await response.json();
const stats = {
  requests: Number(raw.requests || 0),
  delivered: Number(raw.delivered || 0),
  hardBounces: Number(raw.hardBounces || 0),
  softBounces: Number(raw.softBounces || 0),
  blocked: Number(raw.blocked || 0),
  spamReports: Number(raw.spamReports || 0),
  invalid: Number(raw.invalid || 0),
  deferred: Number(raw.deferred || 0),
  unsubscribed: Number(raw.unsubscribed || 0),
};

const evaluation = evaluateDeliverability(stats, thresholds);
const report = {
  generatedAt: new Date().toISOString(),
  window: { days, startDate: isoDate(startDate), endDate: isoDate(endDate), tag: tag || null },
  stats,
  ...evaluation,
};

await mkdir(dirname(output), { recursive: true });
await writeFile(output, `${JSON.stringify(report, null, 2)}\n`, "utf8");

const percent = (value) => `${(value * 100).toFixed(3)}%`;
console.log(`Fenêtre: ${report.window.startDate} → ${report.window.endDate} (${days} j)`);
console.log(`Envois acceptés: ${stats.requests}`);
console.log(`Livraison: ${percent(evaluation.rates.delivery)} | hard ${percent(evaluation.rates.hardBounce)} | soft ${percent(evaluation.rates.softBounce)} | bloqués ${percent(evaluation.rates.blocked)} | plaintes ${percent(evaluation.rates.complaint)} | invalides ${percent(evaluation.rates.invalid)} | différés ${percent(evaluation.rates.deferred)}`);
for (const warning of evaluation.warnings) console.log(`WARN ${warning}`);
for (const violation of evaluation.violations) console.error(`SEUIL DÉPASSÉ ${describeViolation(violation)}`);

console.log(`BREVO_DELIVERABILITY_RESULT=${JSON.stringify({
  ok: evaluation.ok,
  evaluated: evaluation.evaluated,
  sample: evaluation.sample,
  violations: evaluation.violations.map((item) => item.metric),
  warnings: evaluation.warnings,
})}`);
console.log(`Report: ${output}`);

if (!evaluation.ok) process.exit(2);
