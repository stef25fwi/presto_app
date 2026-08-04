#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import {
  latencyPercentiles,
  mergeLatencyBuckets,
} from "../lib/modules/ai/latency_histogram.js";

/**
 * Tendance des métriques IA de production sur fenêtres glissantes.
 *
 * Le rapport ponctuel (`ai:metrics:report`) répond à « comment va la
 * production maintenant ». Ce script répond à « en avons-nous assez mesuré,
 * assez longtemps, et la qualité tient-elle dans la durée » : il exige un
 * nombre minimal de jours réellement observés avant de considérer les seuils
 * comme prouvés.
 */

const WINDOWS = [7, 14, 30];

export function defaultThresholds(env = process.env) {
  return {
    minObservedDays: Number(env.AI_TREND_MIN_OBSERVED_DAYS || 14),
    minSamples: Number(env.AI_TREND_MIN_SAMPLES || 20),
    minSuccessRate: Number(env.AI_TREND_MIN_SUCCESS_RATE || 0.98),
    maxFallbackRate: Number(env.AI_TREND_MAX_FALLBACK_RATE || 0.1),
    maxP95Ms: Number(env.AI_TREND_MAX_P95_MS || 20_000),
    maxDailyCostEur: Number(env.AI_TREND_MAX_DAILY_COST_EUR || 0),
  };
}

function dayKey(date) {
  return date.toISOString().slice(0, 10);
}

export function expectedDays(days, now) {
  const keys = [];
  for (let offset = days - 1; offset >= 0; offset -= 1) {
    keys.push(dayKey(new Date(now.getTime() - offset * 24 * 60 * 60 * 1000)));
  }
  return keys;
}

function accumulate(rows) {
  const totals = {
    count: 0,
    successCount: 0,
    failureCount: 0,
    fallbackCount: 0,
    cacheHitCount: 0,
    totalDurationMs: 0,
    totalAudioSeconds: 0,
    estimatedCostMicrosEur: 0,
  };
  for (const row of rows) {
    for (const key of Object.keys(totals)) {
      totals[key] += Number(row[key] || 0);
    }
  }
  return totals;
}

function windowSummary(rows) {
  const totals = accumulate(rows);
  const percentiles = latencyPercentiles(rows);
  return {
    rows: rows.length,
    count: totals.count,
    successRate: totals.count ? Number((totals.successCount / totals.count).toFixed(4)) : null,
    failureRate: totals.count ? Number((totals.failureCount / totals.count).toFixed(4)) : null,
    fallbackRate: totals.count ? Number((totals.fallbackCount / totals.count).toFixed(4)) : null,
    cacheHitRate: totals.count ? Number((totals.cacheHitCount / totals.count).toFixed(4)) : null,
    averageDurationMs: totals.count ? Math.round(totals.totalDurationMs / totals.count) : null,
    latencyMs: percentiles,
    latencyBuckets: mergeLatencyBuckets(rows),
    totalAudioSeconds: Number(totals.totalAudioSeconds.toFixed(3)),
    estimatedCostEur: Number((totals.estimatedCostMicrosEur / 1_000_000).toFixed(6)),
  };
}

/**
 * Construit la tendance à partir des documents `_ai_metrics_daily`.
 * Fonction pure : la date de référence est injectée pour rester testable.
 */
export function summarizeTrend(rows, options = {}) {
  const days = Math.min(90, Math.max(1, Math.round(options.days || 30)));
  const now = options.now instanceof Date ? options.now : new Date();
  const thresholds = options.thresholds || defaultThresholds();
  const calendar = expectedDays(days, now);
  const start = calendar[0];
  const inRange = rows.filter((row) => String(row.day || "") >= start);

  const perDay = new Map();
  for (const row of inRange) {
    const day = String(row.day || "");
    const bucket = perDay.get(day);
    if (bucket) bucket.push(row);
    else perDay.set(day, [row]);
  }

  const daily = calendar.map((day) => {
    const dayRows = perDay.get(day) || [];
    const summary = windowSummary(dayRows);
    return { day, observed: summary.count > 0, ...summary };
  });

  const observedDays = daily.filter((entry) => entry.observed).length;
  const windows = {};
  for (const window of WINDOWS) {
    if (window > days) continue;
    const keys = new Set(calendar.slice(-window));
    const windowRows = inRange.filter((row) => keys.has(String(row.day || "")));
    windows[`d${window}`] = {
      ...windowSummary(windowRows),
      observedDays: daily.slice(-window).filter((entry) => entry.observed).length,
      days: window,
    };
  }

  const perOperation = new Map();
  for (const row of inRange) {
    const operation = String(row.operation || "unknown");
    const bucket = perOperation.get(operation);
    if (bucket) bucket.push(row);
    else perOperation.set(operation, [row]);
  }

  return {
    generatedAt: now.toISOString(),
    days,
    start,
    end: calendar[calendar.length - 1],
    thresholds,
    observedDays,
    missingDays: daily.filter((entry) => !entry.observed).map((entry) => entry.day),
    accumulationComplete: observedDays >= thresholds.minObservedDays,
    windows,
    byOperation: Object.fromEntries(
      [...perOperation.entries()]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([operation, operationRows]) => [operation, windowSummary(operationRows)]),
    ),
    daily,
  };
}

/** Retourne la liste des manquements ; vide lorsque la tendance est conforme. */
export function evaluateTrendGates(summary) {
  const limits = summary.thresholds;
  const failures = [];
  if (summary.observedDays < limits.minObservedDays) {
    failures.push(
      `jours observés ${summary.observedDays} < ${limits.minObservedDays} — accumulation insuffisante`,
    );
  }
  const reference = summary.windows.d14 || summary.windows.d7 || summary.windows.d30;
  if (!reference || reference.count < limits.minSamples) {
    failures.push(
      `volume insuffisant: ${reference?.count || 0} appels < ${limits.minSamples} — seuils non prouvés`,
    );
    return failures;
  }
  if (reference.successRate !== null && reference.successRate < limits.minSuccessRate) {
    failures.push(`taux de succès ${reference.successRate} < ${limits.minSuccessRate}`);
  }
  if (reference.fallbackRate !== null && reference.fallbackRate > limits.maxFallbackRate) {
    failures.push(`taux de fallback ${reference.fallbackRate} > ${limits.maxFallbackRate}`);
  }
  if ((reference.latencyMs?.p95 || 0) > limits.maxP95Ms) {
    failures.push(`P95 ${reference.latencyMs.p95} ms > ${limits.maxP95Ms} ms`);
  }
  if (limits.maxDailyCostEur > 0) {
    const worstDay = summary.daily
      .filter((entry) => entry.observed)
      .reduce(
        (worst, entry) => (entry.estimatedCostEur > (worst?.estimatedCostEur ?? -1) ? entry : worst),
        null,
      );
    if (worstDay && worstDay.estimatedCostEur > limits.maxDailyCostEur) {
      failures.push(
        `coût ${worstDay.estimatedCostEur} € le ${worstDay.day} > ${limits.maxDailyCostEur} €`,
      );
    }
  }
  return failures;
}

function parseArgs(argv) {
  const options = { days: 30, output: "", enforce: false };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--days") options.days = Number(argv[++index]) || 30;
    else if (value === "--output") options.output = argv[++index] || "";
    else if (value === "--enforce") options.enforce = true;
    else throw new Error(`Unknown argument: ${value}`);
  }
  return options;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const { default: admin } = await import("firebase-admin");
  if (!admin.apps.length) admin.initializeApp();
  const days = Math.min(90, Math.max(1, Math.round(options.days)));
  const start = expectedDays(days, new Date())[0];
  const snapshot = await admin
    .firestore()
    .collection("_ai_metrics_daily")
    .where("day", ">=", start)
    .orderBy("day", "desc")
    .limit(2_000)
    .get();
  const rows = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const summary = summarizeTrend(rows, { days, now: new Date() });
  summary.gateFailures = evaluateTrendGates(summary);
  const output = `${JSON.stringify(summary, null, 2)}\n`;
  if (options.output) await fs.writeFile(path.resolve(options.output), output);
  console.log(output.trimEnd());
  if (options.enforce && summary.gateFailures.length) {
    console.error(`Tendance IA non conforme: ${summary.gateFailures.join(" | ")}`);
    process.exitCode = 1;
  }
}

const invokedDirectly =
  process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename);

if (invokedDirectly) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
