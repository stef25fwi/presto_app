#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import OpenAI, { toFile } from "openai";

import {
  average,
  estimatedTranscriptionCostEur,
  groupBy,
  latencySummary,
  qualitySummary,
} from "./ai_eval_metrics.mjs";
import { probeDurationSeconds } from "./ai_media_probe.mjs";

const REQUIRED_ACCENTS = ["fr-FR", "fr-BE", "fr-CH"];
const REQUIRED_FORMATS = ["wav", "mp3", "ogg", "webm", "flac", "m4a"];

const CONTENT_TYPES = {
  wav: "audio/wav",
  mp3: "audio/mpeg",
  ogg: "audio/ogg",
  webm: "audio/webm",
  flac: "audio/flac",
  m4a: "audio/mp4",
};

function parseArgs(argv) {
  const options = {
    fixture: "evals/transcription_cases.jsonl",
    model: process.env.OPENAI_TRANSCRIBE_MODEL || "gpt-4o-mini-transcribe",
    concurrency: 1,
    dryRun: false,
    jsonOutput: false,
    output: "",
  };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--fixture") options.fixture = argv[++index];
    else if (value === "--model") options.model = argv[++index];
    else if (value === "--concurrency") options.concurrency = Math.max(1, Number(argv[++index]) || 1);
    else if (value === "--dry-run") options.dryRun = true;
    else if (value === "--json-output") options.jsonOutput = true;
    else if (value === "--output") options.output = argv[++index] || "";
    else throw new Error(`Unknown argument: ${value}`);
  }
  return options;
}

function normalize(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9' -]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function words(value) {
  return normalize(value).split(" ").filter(Boolean);
}

function levenshtein(left, right) {
  const a = words(left);
  const b = words(right);
  const row = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (let i = 1; i <= a.length; i += 1) {
    let previous = row[0];
    row[0] = i;
    for (let j = 1; j <= b.length; j += 1) {
      const saved = row[j];
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1));
      previous = saved;
    }
  }
  return { distance: row[b.length], referenceWords: Math.max(1, a.length) };
}

function unexpectedWordRate(expected, actual) {
  const expectedSet = new Set(words(expected));
  const actualWords = words(actual);
  if (!actualWords.length) return 0;
  const unexpected = actualWords.filter((word) => !expectedSet.has(word));
  return unexpected.length / actualWords.length;
}

async function loadJsonl(filePath) {
  const raw = await fs.readFile(filePath, "utf8");
  return raw.split(/\r?\n/).map((line) => line.trim()).filter(Boolean).map((line) => JSON.parse(line));
}

export function fixtureFormat(fixture) {
  const declared = fixture.format || path.extname(fixture.audio || "").replace(".", "");
  return String(declared || "").toLowerCase();
}

export function fixtureAccent(fixture) {
  return String(fixture.accent || fixture.voice || "").trim();
}

/**
 * Un corpus qui ne couvre qu'un accent ou qu'un conteneur ne prouve rien sur
 * la qualité réellement servie : la couverture est donc une condition de
 * validité du jeu d'évaluation, pas une simple statistique.
 */
export function corpusCoverage(fixtures) {
  const accents = [...new Set(fixtures.map(fixtureAccent).filter(Boolean))].sort();
  const formats = [...new Set(fixtures.map(fixtureFormat).filter(Boolean))].sort();
  return {
    accents,
    formats,
    missingAccents: REQUIRED_ACCENTS.filter((accent) => !accents.includes(accent)),
    missingFormats: REQUIRED_FORMATS.filter((format) => !formats.includes(format)),
  };
}

function validateFixture(fixture) {
  if (!fixture.id || !fixture.audio || !fixture.expectedText || !Array.isArray(fixture.entities)) {
    throw new Error(`Invalid fixture: ${JSON.stringify(fixture)}`);
  }
  const format = fixtureFormat(fixture);
  if (!REQUIRED_FORMATS.includes(format)) {
    throw new Error(`Format audio non supporté pour ${fixture.id}: ${format || "absent"}`);
  }
  if (!fixtureAccent(fixture)) {
    throw new Error(`Accent manquant pour ${fixture.id}`);
  }
  const expectedContentType = CONTENT_TYPES[format];
  if (fixture.contentType && fixture.contentType !== expectedContentType) {
    throw new Error(
      `Content-type incohérent pour ${fixture.id}: ${fixture.contentType} au lieu de ${expectedContentType}`,
    );
  }
}

async function runCase(client, options, fixture) {
  const audioPath = path.resolve(path.dirname(options.fixture), fixture.audio);
  const bytes = await fs.readFile(audioPath);
  const format = fixtureFormat(fixture);
  const startedAt = Date.now();
  const response = await client.audio.transcriptions.create({
    file: await toFile(bytes, path.basename(audioPath), {
      type: fixture.contentType || CONTENT_TYPES[format],
    }),
    model: options.model,
    language: fixture.language || "fr",
    prompt: fixture.prompt || "iliprestō, Guadeloupe, Martinique, Baie-Mahault, Les Abymes, Fort-de-France",
  });
  const actual = normalize(response.text);
  const expected = normalize(fixture.expectedText);
  const score = levenshtein(expected, actual);
  const expectedEntities = (fixture.entities || []).map(normalize);
  const missingEntities = expectedEntities.filter((entity) => entity && !actual.includes(entity));
  const durationSeconds = probeDurationSeconds(audioPath) || 0;
  return {
    id: fixture.id,
    accent: fixtureAccent(fixture),
    variant: fixture.variant || null,
    speed: fixture.speed || null,
    format,
    contentType: fixture.contentType || CONTENT_TYPES[format],
    sourceType: fixture.sourceType || "unknown",
    model: options.model,
    providerRequestId: response._request_id || null,
    latencyMs: Date.now() - startedAt,
    audioSeconds: Number(durationSeconds.toFixed(3)),
    sizeBytes: bytes.length,
    wer: Number((score.distance / score.referenceWords).toFixed(4)),
    entityErrorRate: expectedEntities.length
      ? Number((missingEntities.length / expectedEntities.length).toFixed(4))
      : 0,
    hallucinationExtraWordRate: Number(unexpectedWordRate(expected, actual).toFixed(4)),
    missingEntities,
    expectedText: fixture.expectedText,
    actualText: response.text,
  };
}

function thresholds() {
  return {
    maxWer: Number(process.env.AI_EVAL_MAX_WER || 0.35),
    maxEntityErrorRate: Number(process.env.AI_EVAL_MAX_ENTITY_ERROR_RATE || 0.2),
    maxHallucinationRate: Number(process.env.AI_EVAL_MAX_HALLUCINATION_RATE || 0.25),
    maxP95Ms: Number(process.env.AI_EVAL_MAX_P95_MS || 60_000),
    // Un groupe isolé tolère un écart plus large qu'une moyenne globale, mais
    // reste borné : un accent ou un conteneur ne peut pas se dégrader librement.
    maxGroupWer: Number(process.env.AI_EVAL_MAX_GROUP_WER || 0.45),
    maxGroupEntityErrorRate: Number(process.env.AI_EVAL_MAX_GROUP_ENTITY_ERROR_RATE || 0.34),
  };
}

/** Retourne la liste des dépassements ; vide lorsque tous les seuils tiennent. */
export function evaluateGates(summary, limits) {
  const failures = [];
  if (summary.averageWer > limits.maxWer) {
    failures.push(`WER ${summary.averageWer} > ${limits.maxWer}`);
  }
  if (summary.averageEntityErrorRate > limits.maxEntityErrorRate) {
    failures.push(`entity error ${summary.averageEntityErrorRate} > ${limits.maxEntityErrorRate}`);
  }
  if (summary.averageHallucinationExtraWordRate > limits.maxHallucinationRate) {
    failures.push(
      `hallucination ${summary.averageHallucinationExtraWordRate} > ${limits.maxHallucinationRate}`,
    );
  }
  if ((summary.latencyMs?.p95 || 0) > limits.maxP95Ms) {
    failures.push(`P95 ${summary.latencyMs.p95} > ${limits.maxP95Ms}`);
  }
  for (const [dimension, groups] of [
    ["accent", summary.byAccent || {}],
    ["format", summary.byFormat || {}],
  ]) {
    for (const [name, group] of Object.entries(groups)) {
      if (group.averageWer > limits.maxGroupWer) {
        failures.push(`${dimension} ${name}: WER ${group.averageWer} > ${limits.maxGroupWer}`);
      }
      if (group.averageEntityErrorRate > limits.maxGroupEntityErrorRate) {
        failures.push(
          `${dimension} ${name}: entity error ${group.averageEntityErrorRate} > ${limits.maxGroupEntityErrorRate}`,
        );
      }
    }
  }
  if (summary.coverage?.missingAccents?.length) {
    failures.push(`accents manquants: ${summary.coverage.missingAccents.join(", ")}`);
  }
  if (summary.coverage?.missingFormats?.length) {
    failures.push(`formats manquants: ${summary.coverage.missingFormats.join(", ")}`);
  }
  return failures;
}

function enforce(summary) {
  if (String(process.env.AI_EVAL_ENFORCE || "false").toLowerCase() !== "true") return;
  const failures = evaluateGates(summary, thresholds());
  if (failures.length) throw new Error(`Transcription evaluation gate failed: ${failures.join("; ")}`);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const fixturePath = path.resolve(options.fixture);
  options.fixture = fixturePath;
  const fixtures = await loadJsonl(fixturePath);
  if (!fixtures.length) throw new Error("No transcription fixtures found");
  for (const fixture of fixtures) validateFixture(fixture);
  const coverage = corpusCoverage(fixtures);

  if (options.dryRun) {
    if (coverage.missingAccents.length || coverage.missingFormats.length) {
      throw new Error(
        `Couverture insuffisante — accents manquants: ${
          coverage.missingAccents.join(", ") || "aucun"
        }; formats manquants: ${coverage.missingFormats.join(", ") || "aucun"}`,
      );
    }
    console.log(
      JSON.stringify({
        ok: true,
        dryRun: true,
        cases: fixtures.length,
        model: options.model,
        accents: coverage.accents,
        formats: coverage.formats,
      }),
    );
    return;
  }

  if (!process.env.OPENAI_API_KEY) throw new Error("OPENAI_API_KEY is required unless --dry-run is used");
  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 80_000, maxRetries: 1 });
  const results = [];
  for (let index = 0; index < fixtures.length; index += options.concurrency) {
    const chunk = fixtures.slice(index, index + options.concurrency);
    results.push(...await Promise.all(chunk.map((fixture) => runCase(client, options, fixture))));
  }
  const totalAudioSeconds = results.reduce((sum, item) => sum + item.audioSeconds, 0);
  const summary = {
    generatedAt: new Date().toISOString(),
    model: options.model,
    cases: results.length,
    privacyDataset: results.every((item) => item.sourceType === "synthetic"),
    coverage,
    thresholds: thresholds(),
    averageWer: Number(average(results.map((item) => item.wer)).toFixed(4)),
    averageEntityErrorRate: Number(average(results.map((item) => item.entityErrorRate)).toFixed(4)),
    averageHallucinationExtraWordRate: Number(
      average(results.map((item) => item.hallucinationExtraWordRate)).toFixed(4),
    ),
    latencyMs: latencySummary(results.map((item) => item.latencyMs)),
    byAccent: qualitySummary(groupBy(results, (item) => item.accent)),
    byFormat: qualitySummary(groupBy(results, (item) => item.format)),
    totalAudioSeconds: Number(totalAudioSeconds.toFixed(3)),
    estimatedCostEur: estimatedTranscriptionCostEur(totalAudioSeconds),
    results,
  };
  summary.gateFailures = evaluateGates(summary, summary.thresholds);
  enforce(summary);
  const output = JSON.stringify(summary, null, options.jsonOutput ? 0 : 2);
  if (options.output) await fs.writeFile(path.resolve(options.output), `${output}\n`);
  console.log(output);
}

const invokedDirectly =
  process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename);

if (invokedDirectly) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
