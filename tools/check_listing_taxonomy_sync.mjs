#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

async function read(relativePath) {
  return fs.readFile(path.join(root, relativePath), "utf8");
}

function assertContainsAll(label, source, values) {
  const missing = values.filter((value) => !source.includes(value));
  if (missing.length) {
    throw new Error(`${label} missing canonical values: ${missing.join(", ")}`);
  }
}

async function main() {
  const manifest = JSON.parse(await read("shared/listing_taxonomy_v2.json"));
  const listing = await read("functions/src/modules/ai/listing_taxonomy.ts");
  const trade = await read("functions/src/modules/ai/trade_taxonomy.ts");
  const classifier = await read(
    "functions/src/modules/marketplace/callables/classify_service_photo.ts",
  );
  const flutter = await read("lib/config/listing_taxonomy.dart");

  if (
    !manifest.version ||
    !Array.isArray(manifest.listingCategories) ||
    !Array.isArray(manifest.tradeKeys)
  ) {
    throw new Error("Invalid canonical taxonomy manifest");
  }
  for (const [label, source] of [
    ["Backend listing taxonomy", listing],
    ["Backend trade taxonomy", trade],
    ["Flutter taxonomy", flutter],
  ]) {
    if (!source.includes(manifest.version)) {
      throw new Error(`${label} version is not canonical`);
    }
  }
  if (!classifier.includes("TRADE_TAXONOMY_VERSION")) {
    throw new Error("Vision classifier does not expose canonical taxonomy version");
  }

  assertContainsAll("Backend listing taxonomy", listing, manifest.listingCategories);
  assertContainsAll("Backend trade taxonomy", trade, manifest.tradeKeys);
  assertContainsAll("Flutter listing taxonomy", flutter, manifest.listingCategories);
  assertContainsAll("Flutter trade taxonomy", flutter, manifest.tradeKeys);

  console.log(
    JSON.stringify({
      ok: true,
      version: manifest.version,
      listingCategories: manifest.listingCategories.length,
      tradeKeys: manifest.tradeKeys.length,
    }),
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
