#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import OpenAI, { toFile } from "openai";

import {
  average,
  estimatedTranscriptionCostEur,
  latencySummary,
} from "./ai_eval_metrics.mjs";

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

function wavDurationSeconds(buffer) {
  if (buffer.length < 44 || buffer.toString("ascii", 0, 4) !== "RIFF") return 0;
  const byteRate = buffer.readUInt32LE(28);
  if (!byteRate) return 0;
  let offset = 12;
  while (offset + 8 <= buffer.length) {
    const id = buffer.toString("ascii", offset, offset + 4);
    const size = buffer.readUInt32LE(offset + 4);
    if (id === "data") return size / byteRate;
    offset += 8 + size + (size % 2);
  }
  return 0;
}

async function loadJsonl(filePath) {
  const raw = await fs.readFile(filePath, "utf8");
  return raw.split(/\r?\n/).map((line) => line.trim()).filter(Boolean).map((line) => JSON.parse(line));
}

async function runCase(client, options, fixture) {
  const audioPath = path.resolve(path.dirname(options.fixture), fixture.audio);
  const bytes = await fs.readFile(audioPath);
  const startedAt = Date.now();
  const response = await client.audio.transcriptions.create({
    file: await toFile(bytes, path.basename(audioPath)),
    model: options.model,
    language: fixture.language || "fr",
    prompt: fixture.prompt || "iliprestō, Guadeloupe, Martinique, Baie-Mahault, Les Abymes, Fort-de-France",
  });
  const actual = normalize(response.text);
  const expected = normalize(fixture.expectedText);
  const score = levenshtein(expected, actual);
  const expectedEntities = (fixture.entities || []).map(normalize);
  const missingEntities = expectedEntities.filter((entity) => entity && !actual.includes(entity));
  const durationSeconds = wavDurationSeconds(bytes);
  return {
    id: fixture.id,
    sourceType: fixture.sourceType || "unknown",
    model: options.model,
    providerRequestId: response._request_id || null,
    latencyMs: Date.now() - startedAt,
    audioSeconds: Number(durationSeconds.toFixed(3)),
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

function enforce(summary) {
  if (String(process.env.AI_EVAL_ENFORCE || "false").toLowerCase() !== "true") return;
  const maxWer = Number(process.env.AI_EVAL_MAX_WER || 0.35);
  const maxEntityErrorRate = Number(process.env.AI_EVAL_MAX_ENTITY_ERROR_RATE || 0.2);
  const maxHallucinationRate = Number(process.env.AI_EVAL_MAX_HALLUCINATION_RATE || 0.25);
  const maxP95Ms = Number(process.env.AI_EVAL_MAX_P95_MS || 60_000);
  const failures = [];
  if (summary.averageWer > maxWer) failures.push(`WER ${summary.averageWer} > ${maxWer}`);
  if (summary.averageEntityErrorRate > maxEntityErrorRate) {
    failures.push(`entity error ${summary.averageEntityErrorRate} > ${maxEntityErrorRate}`);
  }
  if (summary.averageHallucinationExtraWordRate > maxHallucinationRate) {
    failures.push(`hallucination ${summary.averageHallucinationExtraWordRate} > ${maxHallucinationRate}`);
  }
  if ((summary.latencyMs.p95 || 0) > maxP95Ms) failures.push(`P95 ${summary.latencyMs.p95} > ${maxP95Ms}`);
  if (failures.length) throw new Error(`Transcription evaluation gate failed: ${failures.join("; ")}`);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const fixturePath = path.resolve(options.fixture);
  options.fixture = fixturePath;
  const fixtures = await loadJsonl(fixturePath);
  if (!fixtures.length) throw new Error("No transcription fixtures found");

  if (options.dryRun) {
    for (const fixture of fixtures) {
      if (!fixture.id || !fixture.audio || !fixture.expectedText || !Array.isArray(fixture.entities)) {
        throw new Error(`Invalid fixture: ${JSON.stringify(fixture)}`);
      }
    }
    console.log(JSON.stringify({ ok: true, dryRun: true, cases: fixtures.length, model: options.model }));
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
    averageWer: Number(average(results.map((item) => item.wer)).toFixed(4)),
    averageEntityErrorRate: Number(average(results.map((item) => item.entityErrorRate)).toFixed(4)),
    averageHallucinationExtraWordRate: Number(
      average(results.map((item) => item.hallucinationExtraWordRate)).toFixed(4),
    ),
    latencyMs: latencySummary(results.map((item) => item.latencyMs)),
    totalAudioSeconds: Number(totalAudioSeconds.toFixed(3)),
    estimatedCostEur: estimatedTranscriptionCostEur(totalAudioSeconds),
    results,
  };
  enforce(summary);
  const output = JSON.stringify(summary, null, options.jsonOutput ? 0 : 2);
  if (options.output) await fs.writeFile(path.resolve(options.output), `${output}\n`);
  console.log(output);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
