#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import OpenAI from "openai";

const root = path.resolve(import.meta.dirname, "..");
const fixturePath = process.argv[2] || path.join(root, "evals", "listing_cases.jsonl");
const outputPath = process.argv[3] || path.join(root, "evals", "listing_eval_report.json");
const model = process.env.OPENAI_LISTING_MODEL || "gpt-4o-mini";
const apiKey = process.env.OPENAI_API_KEY;

if (!apiKey) {
  console.error("OPENAI_API_KEY is required for the live evaluation.");
  process.exit(2);
}

const categories = [
  "Jardinage",
  "Bricolage / Travaux",
  "Aide à domicile",
  "Restauration / Extra",
  "Événementiel / DJ",
  "Garde d'enfants",
  "Cours & soutien",
  "Peinture",
  "Main-d'œuvre",
  "Autre",
];

const responseFormat = {
  type: "json_schema",
  json_schema: {
    name: "ilipresto_listing_eval",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        title: { type: ["string", "null"] },
        description: { type: ["string", "null"] },
        category: {
          anyOf: [
            { type: "string", enum: categories },
            { type: "null" },
          ],
        },
        city: { type: ["string", "null"] },
      },
      required: ["title", "description", "category", "city"],
    },
  },
};

const systemPrompt = `Tu es l'assistant de rédaction d'annonces de l'application iliprestō.

Transforme uniquement les informations réellement présentes dans le texte en un brouillon clair et fidèle.

Règles absolues :
- N'invente aucune information, aucun prix, aucune urgence, aucune disponibilité et aucune qualification.
- Utilise null lorsqu'une donnée est absente ou ambiguë.
- Corrige seulement les hésitations, répétitions et erreurs évidentes de transcription.
- Le titre doit être spécifique, naturel et court.
- La description doit être publiable, fidèle et concise.
- La catégorie doit provenir exclusivement de l'enum du schéma.
- La ville fournie dans le texte ne doit être normalisée que si elle est explicitement identifiable.
- Respecte strictement le schéma de sortie.`;

const source = await fs.readFile(fixturePath, "utf8");
const cases = source
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean)
  .map((line) => JSON.parse(line));

const client = new OpenAI({ apiKey, timeout: 25_000, maxRetries: 1 });
const results = [];

for (const item of cases) {
  const startedAt = Date.now();
  try {
    const completion = await client.chat.completions.create({
      model,
      temperature: 0,
      max_tokens: 220,
      response_format: responseFormat,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: item.input },
      ],
    });
    const parsed = JSON.parse(completion.choices[0]?.message?.content || "{}");
    const searchable = `${parsed.title || ""} ${parsed.description || ""}`.toLowerCase();
    const categoryPass = parsed.category === item.expectedCategory;
    const cityPass = parsed.city === item.expectedCity;
    const contentPass = (item.mustInclude || []).every((needle) =>
      searchable.includes(String(needle).toLowerCase()),
    );
    results.push({
      id: item.id,
      success: categoryPass && cityPass && contentPass,
      categoryPass,
      cityPass,
      contentPass,
      expected: {
        category: item.expectedCategory,
        city: item.expectedCity,
      },
      actual: parsed,
      durationMs: Date.now() - startedAt,
      usage: completion.usage || null,
      requestId: completion._request_id || null,
    });
  } catch (error) {
    results.push({
      id: item.id,
      success: false,
      durationMs: Date.now() - startedAt,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

const passed = results.filter((item) => item.success).length;
const report = {
  generatedAt: new Date().toISOString(),
  model,
  promptParity: "ilipresto-listing-v3",
  fixturePath,
  total: results.length,
  passed,
  failed: results.length - passed,
  passRate: results.length ? passed / results.length : 0,
  results,
};

await fs.writeFile(outputPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
console.log(JSON.stringify({
  model,
  total: report.total,
  passed: report.passed,
  failed: report.failed,
  passRate: report.passRate,
  outputPath,
}, null, 2));

process.exit(report.failed === 0 ? 0 : 1);
