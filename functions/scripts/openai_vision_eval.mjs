#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import OpenAI from "openai";

function parseArgs(argv) {
  const options = {
    fixture: "evals/vision_cases.jsonl",
    model: process.env.OPENAI_VISION_MODEL || "gpt-4o-mini-2024-07-18",
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

async function loadJsonl(filePath) {
  const raw = await fs.readFile(filePath, "utf8");
  return raw.split(/\r?\n/).map((line) => line.trim()).filter(Boolean).map((line) => JSON.parse(line));
}

function mimeFromPath(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  if (extension === ".png") return "image/png";
  if (extension === ".webp") return "image/webp";
  return "image/jpeg";
}

const RESPONSE_FORMAT = {
  type: "json_schema",
  json_schema: {
    name: "ilipresto_vision_eval",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        metier: { type: ["string", "null"] },
        confidence: { type: "number", minimum: 0, maximum: 1 },
      },
      required: ["metier", "confidence"],
    },
  },
};

async function runCase(client, options, fixture) {
  const imagePath = path.resolve(path.dirname(options.fixture), fixture.image);
  const bytes = await fs.readFile(imagePath);
  const dataUrl = `data:${mimeFromPath(imagePath)};base64,${bytes.toString("base64")}`;
  const startedAt = Date.now();
  const response = await client.chat.completions.create({
    model: options.model,
    temperature: 0,
    max_tokens: 64,
    response_format: RESPONSE_FORMAT,
    messages: [
      {
        role: "system",
        content: "Classe l'image pour iliprestō. Retourne le métier principal visible ou null. N'invente aucun contexte.",
      },
      {
        role: "user",
        content: [{ type: "image_url", image_url: { url: dataUrl, detail: "low" } }],
      },
    ],
  });
  const parsed = JSON.parse(response.choices[0]?.message?.content || "{}");
  const actual = parsed.metier ?? null;
  return {
    id: fixture.id,
    expected: fixture.expectedMetier ?? null,
    actual,
    confidence: Number(parsed.confidence || 0),
    correct: actual === (fixture.expectedMetier ?? null),
    latencyMs: Date.now() - startedAt,
  };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  options.fixture = path.resolve(options.fixture);
  const fixtures = await loadJsonl(options.fixture);
  if (!fixtures.length) throw new Error("No vision fixtures found");

  if (options.dryRun) {
    for (const fixture of fixtures) {
      if (!fixture.id || !fixture.image || !("expectedMetier" in fixture)) {
        throw new Error(`Invalid fixture: ${JSON.stringify(fixture)}`);
      }
    }
    console.log(JSON.stringify({ ok: true, dryRun: true, cases: fixtures.length, model: options.model }));
    return;
  }

  if (!process.env.OPENAI_API_KEY) throw new Error("OPENAI_API_KEY is required unless --dry-run is used");
  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 30_000, maxRetries: 1 });
  const results = [];
  for (let index = 0; index < fixtures.length; index += options.concurrency) {
    const chunk = fixtures.slice(index, index + options.concurrency);
    results.push(...await Promise.all(chunk.map((fixture) => runCase(client, options, fixture))));
  }
  const correct = results.filter((result) => result.correct).length;
  const summary = {
    model: options.model,
    cases: results.length,
    exactAccuracy: Number((correct / results.length).toFixed(4)),
    averageLatencyMs: Math.round(results.reduce((sum, item) => sum + item.latencyMs, 0) / results.length),
    results,
  };
  console.log(options.jsonOutput ? JSON.stringify(summary) : JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
