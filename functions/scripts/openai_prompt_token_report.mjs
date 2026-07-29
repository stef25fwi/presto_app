#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const ROOT = path.resolve(process.cwd(), "src/modules/ai");
const TARGETS = [
  "listing_pipeline.ts",
  "listing_taxonomy.ts",
  "micro_ia_callable.ts",
];

function estimateTokens(text) {
  return Math.ceil(Buffer.byteLength(text, "utf8") / 4);
}

async function main() {
  const rows = [];
  for (const file of TARGETS) {
    const absolute = path.join(ROOT, file);
    const content = await fs.readFile(absolute, "utf8");
    const prompts = [...content.matchAll(/(?:SYSTEM_PROMPT|PROMPT|CONTEXT)[^=]*=\s*`([\s\S]*?)`/g)]
      .map((match) => match[1]);
    rows.push({
      file,
      promptBlocks: prompts.length,
      estimatedTokens: prompts.reduce((sum, prompt) => sum + estimateTokens(prompt), 0),
      cacheEligibleBlocks: prompts.filter((prompt) => estimateTokens(prompt) >= 1024).length,
    });
  }
  const report = {
    generatedAt: new Date().toISOString(),
    methodology: "UTF-8 bytes / 4; approximation only",
    totals: {
      promptBlocks: rows.reduce((sum, row) => sum + row.promptBlocks, 0),
      estimatedTokens: rows.reduce((sum, row) => sum + row.estimatedTokens, 0),
      cacheEligibleBlocks: rows.reduce((sum, row) => sum + row.cacheEligibleBlocks, 0),
    },
    files: rows,
  };
  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
