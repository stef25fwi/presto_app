#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import OpenAI, { toFile } from "openai";

function parseArgs(argv) {
  const options = {
    fixture: "evals/transcription_cases.jsonl",
    model: process.env.OPENAI_TRANSCRIBE_MODEL || "gpt-4o-mini-transcribe-2025-12-15",
    concurrency: 1,
    dryRun: false,
    jsonOutput: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--fixture") options.fixture = argv[++index];
    else if (value === "--model") options.model = argv[++index];
    else if (value === "--concurrency") options.concurrency = Math.max(1, Number(argv[++index]) || 1);
    else if (value === "--dry-run") options.dryRun = true;
    else if (value === "--json-output") options.jsonOutput = true;
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

function levenshtein(left, right) {
  const a = left.split(" ").filter(Boolean);
  const b = right.split(" ").filter(Boolean);
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
  return {
    id: fixture.id,
    model: options.model,
    latencyMs: Date.now() - startedAt,
    wer: Number((score.distance / score.referenceWords).toFixed(4)),
    entityErrorRate: expectedEntities.length
      ? Number((missingEntities.length / expectedEntities.length).toFixed(4))
      : 0,
    missingEntities,
  };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const fixturePath = path.resolve(options.fixture);
  options.fixture = fixturePath;
  const fixtures = await loadJsonl(fixturePath);
  if (!fixtures.length) throw new Error("No transcription fixtures found");

  if (options.dryRun) {
    for (const fixture of fixtures) {
      if (!fixture.id || !fixture.audio || !fixture.expectedText) {
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
  const summary = {
    model: options.model,
    cases: results.length,
    averageWer: Number((results.reduce((sum, item) => sum + item.wer, 0) / results.length).toFixed(4)),
    averageEntityErrorRate: Number((results.reduce((sum, item) => sum + item.entityErrorRate, 0) / results.length).toFixed(4)),
    averageLatencyMs: Math.round(results.reduce((sum, item) => sum + item.latencyMs, 0) / results.length),
    results,
  };
  console.log(options.jsonOutput ? JSON.stringify(summary) : JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
