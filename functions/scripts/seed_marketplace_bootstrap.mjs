#!/usr/bin/env node

import admin from 'firebase-admin';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

function parseArgs(argv) {
  const opts = {
    dryRun: false,
    projectId: process.env.GCLOUD_PROJECT || '',
    citiesLimit: 0,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') {
      opts.dryRun = true;
      continue;
    }
    if (arg.startsWith('--project=')) {
      opts.projectId = arg.slice('--project='.length).trim();
      continue;
    }
    if (arg.startsWith('--cities-limit=')) {
      const parsed = Number(arg.slice('--cities-limit='.length));
      if (!Number.isNaN(parsed) && parsed > 0) {
        opts.citiesLimit = Math.floor(parsed);
      }
    }
  }

  return opts;
}

function slugify(input) {
  return String(input || '')
    .trim()
    .toLowerCase()
    .replace(/[àâä]/g, 'a')
    .replace(/ç/g, 'c')
    .replace(/[éèêë]/g, 'e')
    .replace(/[îï]/g, 'i')
    .replace(/[ôö]/g, 'o')
    .replace(/[ùûü]/g, 'u')
    .replace(/œ/g, 'oe')
    .replace(/[\/\-'’']/g, ' ')
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/ /g, '-');
}

function uniqueStrings(values) {
  return Array.from(
    new Set(
      values
        .map((value) => String(value || '').trim())
        .filter(Boolean),
    ),
  );
}

function buildCityDocs(rawCities, citiesLimit) {
  const docs = [];

  for (const entry of rawCities) {
    const label = String(entry?.name || '').trim();
    const departmentCode = String(entry?.dept || '').trim();
    const postalCodes = uniqueStrings(Array.isArray(entry?.cps) ? entry.cps : []);
    if (!label || postalCodes.length === 0) {
      continue;
    }

    const slug = slugify(label);
    for (const postalCode of postalCodes) {
      const id = `${postalCode}_${slug}`;
      docs.push({
        id,
        slug,
        label,
        postalCodes,
        primaryPostalCode: postalCode,
        departmentCode: departmentCode || null,
        isActive: true,
      });

      if (citiesLimit > 0 && docs.length >= citiesLimit) {
        return docs;
      }
    }
  }

  return docs;
}

async function readJson(filePath) {
  const raw = await fs.readFile(filePath, 'utf8');
  return JSON.parse(raw);
}

async function main() {
  const opts = parseArgs(process.argv);
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  const functionsDir = path.resolve(scriptDir, '..');
  const repoRoot = path.resolve(functionsDir, '..');

  const categoriesPath = path.join(functionsDir, 'seeds', 'marketplace_categories.json');
  const appConfigPath = path.join(functionsDir, 'seeds', 'app_config.marketplace.json');
  const citiesPath = path.join(repoRoot, 'assets', 'data', 'cities_compact.json');

  const [rawCategories, rawAppConfig, rawCities] = await Promise.all([
    readJson(categoriesPath),
    readJson(appConfigPath),
    readJson(citiesPath),
  ]);

  const categories = Array.isArray(rawCategories) ? rawCategories : [];
  const cityDocs = buildCityDocs(Array.isArray(rawCities) ? rawCities : [], opts.citiesLimit);

  if (!admin.apps.length) {
    const init = opts.projectId ? { projectId: opts.projectId } : {};
    admin.initializeApp(init);
  }

  const db = admin.firestore();

  if (opts.dryRun) {
    console.log('--- marketplace bootstrap dry-run ---');
    console.log(`categories: ${categories.length}`);
    console.log(`cities: ${cityDocs.length}`);
    console.log('appConfig doc: appConfig/marketplace');
    if (categories[0]) {
      console.log(`sample category: ${categories[0].id} -> ${categories[0].label}`);
    }
    if (cityDocs[0]) {
      console.log(`sample city: ${cityDocs[0].id} -> ${cityDocs[0].label}`);
    }
    return;
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  let batch = db.batch();
  let batchCount = 0;
  let writes = 0;
  const MAX_BATCH = 450;

  async function enqueue(ref, data) {
    batch.set(ref, {
      ...data,
      updatedAt: now,
      createdAt: data.createdAt ?? now,
    }, { merge: true });
    batchCount += 1;
    writes += 1;

    if (batchCount >= MAX_BATCH) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  for (const category of categories) {
    const id = String(category.id || category.slug || '').trim();
    if (!id) {
      continue;
    }
    await enqueue(db.collection('categories').doc(id), {
      id,
      slug: String(category.slug || id).trim(),
      label: String(category.label || '').trim(),
      isActive: category.isActive !== false,
      searchableKeywords: uniqueStrings(category.searchableKeywords || []),
    });
  }

  await enqueue(db.collection('appConfig').doc('marketplace'), {
    id: 'marketplace',
    moderation: rawAppConfig.moderation || {},
    antiSpam: rawAppConfig.antiSpam || {},
  });

  for (const city of cityDocs) {
    await enqueue(db.collection('cities').doc(city.id), {
      id: city.id,
      slug: city.slug,
      label: city.label,
      postalCodes: city.postalCodes,
      primaryPostalCode: city.primaryPostalCode,
      departmentCode: city.departmentCode,
      isActive: city.isActive,
    });
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log('--- marketplace bootstrap summary ---');
  console.log(`categories seeded: ${categories.length}`);
  console.log(`cities seeded: ${cityDocs.length}`);
  console.log('appConfig seeded: 1');
  console.log(`total writes: ${writes}`);
}

main().catch((error) => {
  console.error('[seed_marketplace_bootstrap] failed:', error);
  process.exitCode = 1;
});