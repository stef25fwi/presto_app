#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

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
  const backend = await read("functions/src/modules/ai/listing_taxonomy.ts");
  const vision = await read(
    "functions/src/modules/marketplace/callables/classify_service_photo.ts",
  );
  const flutter = await read("lib/config/listing_taxonomy.dart");

  if (!manifest.version || !Array.isArray(manifest.listingCategories)) {
    throw new Error("Invalid canonical taxonomy manifest");
  }
  if (!backend.includes(manifest.version)) {
    throw new Error("Backend listing taxonomy version is not canonical");
  }
  if (!vision.includes(manifest.version)) {
    throw new Error("Vision taxonomy version is not canonical");
  }
  if (!flutter.includes(manifest.version)) {
    throw new Error("Flutter taxonomy version is not canonical");
  }

  assertContainsAll("Backend listing taxonomy", backend, manifest.listingCategories);
  assertContainsAll("Vision taxonomy", vision, manifest.tradeKeys);
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
