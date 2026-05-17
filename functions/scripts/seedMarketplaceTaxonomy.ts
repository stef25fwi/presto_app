import fs from "node:fs/promises";
import path from "node:path";

import admin from "firebase-admin";

import { initAdmin, parseCommonArgs, slugify } from "./_shared";

async function readJson(filePath: string) {
  return JSON.parse(await fs.readFile(filePath, "utf8")) as unknown;
}

async function main() {
  const options = parseCommonArgs(process.argv);
  const db = initAdmin(options.projectId);
  const rootDir = path.resolve(__dirname, "..", "..");
  const functionsDir = path.resolve(__dirname, "..");

  const [categoriesRaw, citiesRaw] = await Promise.all([
    readJson(path.join(functionsDir, "seeds", "marketplace_categories.json")),
    readJson(path.join(rootDir, "assets", "data", "cities_compact.json")),
  ]);

  const categories = Array.isArray(categoriesRaw) ? categoriesRaw as Array<Record<string, unknown>> : [];
  const cities = Array.isArray(citiesRaw) ? citiesRaw as Array<Record<string, unknown>> : [];

  let batch = db.batch();
  let batchCount = 0;
  let writes = 0;

  for (const category of categories) {
    const id = String(category.id || category.slug || "").trim();
    if (!id) continue;
    const payload = {
      id,
      slug: String(category.slug || id).trim(),
      label: String(category.label || "").trim(),
      isActive: category.isActive !== false,
      searchableKeywords: Array.isArray(category.searchableKeywords)
        ? category.searchableKeywords
        : [String(category.label || "").trim(), id],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (options.dryRun) {
      writes += 1;
      continue;
    }

    batch.set(db.collection("categories").doc(id), payload, { merge: true });
    batchCount += 1;
    writes += 1;
  }

  for (const city of cities) {
    const label = String(city.name || "").trim();
    const postalCodes = Array.isArray(city.cps) ? city.cps.map((value) => String(value || "").trim()).filter(Boolean) : [];
    if (!label || postalCodes.length === 0) continue;
    const slug = slugify(label);
    for (const postalCode of postalCodes) {
      const id = `${postalCode}_${slug}`;
      const payload = {
        id,
        slug,
        label,
        postalCodes,
        primaryPostalCode: postalCode,
        departmentCode: String(city.dept || "").trim() || null,
        regionCode: String(city.region || "").trim() || null,
        isActive: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (options.dryRun) {
        writes += 1;
        continue;
      }

      batch.set(db.collection("cities").doc(id), payload, { merge: true });
      batchCount += 1;
      writes += 1;
      if (batchCount >= 400) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }
  }

  if (!options.dryRun && batchCount > 0) {
    await batch.commit();
  }

  console.log(JSON.stringify({ dryRun: options.dryRun, writes }, null, 2));
}

void main().catch((error) => {
  console.error("[seedMarketplaceTaxonomy] failed", error);
  process.exitCode = 1;
});