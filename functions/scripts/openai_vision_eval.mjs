#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import OpenAI from "openai";

import {
  average,
  estimatedVisionCostEur,
  groupBy,
  latencySummary,
} from "./ai_eval_metrics.mjs";

function parseArgs(argv) {
  const options = {
    fixture: "evals/vision_cases.jsonl",
    model: process.env.OPENAI_VISION_MODEL || "gpt-4o-mini",
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

async function loadJsonl(filePath) {
  const raw = await fs.readFile(filePath, "utf8");
  return raw.split(/\r?\n/).map((line) => line.trim()).filter(Boolean).map((line) => JSON.parse(line));
}

const REQUIRED_IMAGE_FORMATS = ["jpg", "png", "webp"];

function mimeFromPath(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  if (extension === ".png") return "image/png";
  if (extension === ".webp") return "image/webp";
  return "image/jpeg";
}

function fixtureFormat(fixture) {
  const declared = fixture.format || path.extname(fixture.image || "").replace(".", "");
  const format = String(declared || "").toLowerCase();
  return format === "jpeg" ? "jpg" : format;
}

/**
 * La classification photo accepte jpeg, png et webp : la preuve de qualité
 * doit couvrir les trois conteneurs, pas seulement celui du corpus initial.
 */
function corpusCoverage(fixtures) {
  const formats = [...new Set(fixtures.map(fixtureFormat).filter(Boolean))].sort();
  return {
    formats,
    missingFormats: REQUIRED_IMAGE_FORMATS.filter((format) => !formats.includes(format)),
  };
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

function parseStructuredOutput(content) {
  try {
    const parsed = JSON.parse(content || "{}");
    const keys = Object.keys(parsed).sort();
    const validKeys = keys.length === 2 && keys[0] === "confidence" && keys[1] === "metier";
    const validMetier = parsed.metier === null || typeof parsed.metier === "string";
    const confidence = Number(parsed.confidence);
    const validConfidence = Number.isFinite(confidence) && confidence >= 0 && confidence <= 1;
    return {
      parsed,
      schemaValid: validKeys && validMetier && validConfidence,
    };
  } catch {
    return { parsed: {}, schemaValid: false };
  }
}

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
  const structured = parseStructuredOutput(response.choices[0]?.message?.content || "");
  const actual = structured.parsed.metier ?? null;
  const expected = fixture.expectedMetier ?? null;
  const usage = response.usage || {};
  return {
    id: fixture.id,
    sourceType: fixture.sourceType || "synthetic",
    format: fixtureFormat(fixture),
    contentType: mimeFromPath(imagePath),
    expected,
    actual,
    confidence: Number(structured.parsed.confidence || 0),
    correct: actual === expected,
    hallucinated: expected === null && actual !== null,
    schemaValid: structured.schemaValid,
    latencyMs: Date.now() - startedAt,
    providerRequestId: response._request_id || null,
    inputTokens: Number(usage.prompt_tokens || 0),
    outputTokens: Number(usage.completion_tokens || 0),
  };
}

function enforce(summary) {
  if (String(process.env.AI_EVAL_ENFORCE || "false").toLowerCase() !== "true") return;
  const minAccuracy = Number(process.env.AI_EVAL_MIN_VISION_ACCURACY || 0.66);
  const maxHallucinationRate = Number(process.env.AI_EVAL_MAX_VISION_HALLUCINATION_RATE || 0.1);
  const minSchemaRate = Number(process.env.AI_EVAL_MIN_SCHEMA_VALID_RATE || 1);
  const maxP95Ms = Number(process.env.AI_EVAL_MAX_P95_MS || 30_000);
  const failures = [];
  if (summary.exactAccuracy < minAccuracy) failures.push(`accuracy ${summary.exactAccuracy} < ${minAccuracy}`);
  if (summary.hallucinationRate > maxHallucinationRate) {
    failures.push(`hallucination ${summary.hallucinationRate} > ${maxHallucinationRate}`);
  }
  if (summary.schemaValidRate < minSchemaRate) {
    failures.push(`schema ${summary.schemaValidRate} < ${minSchemaRate}`);
  }
  if ((summary.latencyMs.p95 || 0) > maxP95Ms) failures.push(`P95 ${summary.latencyMs.p95} > ${maxP95Ms}`);
  if (summary.coverage?.missingFormats?.length) {
    failures.push(`formats image manquants: ${summary.coverage.missingFormats.join(", ")}`);
  }
  // Une moyenne globale correcte ne doit pas masquer un conteneur qui échoue :
  // chaque format est mesuré séparément sur la validité de schéma.
  for (const [format, group] of Object.entries(summary.byFormat || {})) {
    if (group.schemaValidRate < minSchemaRate) {
      failures.push(`format ${format}: schéma ${group.schemaValidRate} < ${minSchemaRate}`);
    }
  }
  if (failures.length) throw new Error(`Vision evaluation gate failed: ${failures.join("; ")}`);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  options.fixture = path.resolve(options.fixture);
  const fixtures = await loadJsonl(options.fixture);
  if (!fixtures.length) throw new Error("No vision fixtures found");

  const coverage = corpusCoverage(fixtures);

  if (options.dryRun) {
    for (const fixture of fixtures) {
      if (!fixture.id || !fixture.image || !("expectedMetier" in fixture)) {
        throw new Error(`Invalid fixture: ${JSON.stringify(fixture)}`);
      }
    }
    if (coverage.missingFormats.length) {
      throw new Error(`Formats image manquants: ${coverage.missingFormats.join(", ")}`);
    }
    console.log(
      JSON.stringify({
        ok: true,
        dryRun: true,
        cases: fixtures.length,
        model: options.model,
        formats: coverage.formats,
      }),
    );
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
  const ambiguousCases = results.filter((result) => result.expected === null);
  const hallucinated = ambiguousCases.filter((result) => result.hallucinated).length;
  const schemaValid = results.filter((result) => result.schemaValid).length;
  const inputTokens = results.reduce((sum, result) => sum + result.inputTokens, 0);
  const outputTokens = results.reduce((sum, result) => sum + result.outputTokens, 0);
  const summary = {
    generatedAt: new Date().toISOString(),
    model: options.model,
    cases: results.length,
    privacyDataset: results.every((result) => result.sourceType === "synthetic"),
    coverage,
    exactAccuracy: Number((correct / results.length).toFixed(4)),
    hallucinationRate: Number(
      (ambiguousCases.length ? hallucinated / ambiguousCases.length : 0).toFixed(4),
    ),
    schemaValidRate: Number((schemaValid / results.length).toFixed(4)),
    byFormat: Object.fromEntries(
      Object.entries(groupBy(results, (result) => result.format)).map(([format, items]) => [
        format,
        {
          cases: items.length,
          exactAccuracy: Number(
            (items.filter((item) => item.correct).length / items.length).toFixed(4),
          ),
          schemaValidRate: Number(
            (items.filter((item) => item.schemaValid).length / items.length).toFixed(4),
          ),
          latencyMs: latencySummary(items.map((item) => item.latencyMs)),
        },
      ]),
    ),
    averageConfidence: Number(average(results.map((result) => result.confidence)).toFixed(4)),
    latencyMs: latencySummary(results.map((result) => result.latencyMs)),
    usage: { inputTokens, outputTokens },
    estimatedCostEur: estimatedVisionCostEur(inputTokens, outputTokens),
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
