#!/usr/bin/env node

import admin from 'firebase-admin';

function parseArgs(argv) {
  const opts = {
    dryRun: false,
    limit: 0,
    projectId: process.env.GCLOUD_PROJECT || '',
  };

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') {
      opts.dryRun = true;
      continue;
    }
    if (a.startsWith('--limit=')) {
      const n = Number(a.slice('--limit='.length));
      if (!Number.isNaN(n) && n > 0) opts.limit = Math.floor(n);
      continue;
    }
    if (a.startsWith('--project=')) {
      opts.projectId = a.slice('--project='.length).trim();
      continue;
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
    .replace(/[\/\-’']/g, ' ')
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/ /g, '-');
}

function normalizeText(input) {
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
    .replace(/[\/\-’']/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const CATEGORIES = [
  'Restauration / Extra',
  'Bricolage / Travaux',
  'Aide à domicile',
  "Garde d'enfants",
  'Événementiel / DJ',
  'Cours & soutien',
  'Jardinage',
  'Peinture',
  "Main-d'œuvre",
  'Autre',
];

const CATEGORY_ALIASES = {
  bricolage: 'Bricolage / Travaux',
  'bricolage travaux': 'Bricolage / Travaux',
  travaux: 'Bricolage / Travaux',
  'aide a domicile': 'Aide à domicile',
  'aide domicile': 'Aide à domicile',
  'garde enfants': "Garde d'enfants",
  'garde d enfants': "Garde d'enfants",
  'dj sono': 'Événementiel / DJ',
  'evenementiel dj': 'Événementiel / DJ',
  evenementiel: 'Événementiel / DJ',
  'cours soutien': 'Cours & soutien',
  'cours et soutien': 'Cours & soutien',
  'main d oeuvre': "Main-d'œuvre",
  'main oeuvre': "Main-d'œuvre",
  autres: 'Autre',
};

function canonicalizeCategory(input) {
  const raw = String(input || '').trim();
  if (!raw) return 'Autre';

  const normalized = normalizeText(raw);
  if (CATEGORY_ALIASES[normalized]) {
    return CATEGORY_ALIASES[normalized];
  }

  let best = null;
  let bestScore = -1;
  for (const category of CATEGORIES) {
    const candidate = normalizeText(category);
    let score = -1;
    if (candidate === normalized) {
      score = 10000;
    } else if (candidate.includes(normalized) && normalized.length >= 2) {
      score = 5000 + normalized.length;
    } else if (normalized.includes(candidate) && candidate.length >= 2) {
      score = 3000 + candidate.length;
    }

    if (score > bestScore) {
      bestScore = score;
      best = category;
    }
  }

  return bestScore > 0 ? best : raw;
}

function departmentFromPostalCode(postalCode) {
  const cp = String(postalCode || '').trim();
  if (cp.length < 2) return null;
  if (cp.startsWith('97') || cp.startsWith('98')) {
    return cp.length >= 3 ? cp.slice(0, 3) : cp;
  }
  return cp.slice(0, 2);
}

function budgetValueFromAny(rawBudget) {
  if (rawBudget === null || rawBudget === undefined) return null;
  if (typeof rawBudget === 'number') return rawBudget;

  const normalized = String(rawBudget)
    .trim()
    .replace(/€/g, '')
    .replace(/\s+/g, '')
    .replace(/,/g, '.');

  if (!normalized) return null;
  const n = Number(normalized);
  return Number.isFinite(n) ? n : null;
}

function buildPatch(data) {
  const category = canonicalizeCategory(data.category);
  const city = String(data.city ?? data.location ?? '').trim();
  const postalCode = String(data.postalCode ?? data.cp ?? '').trim();
  const categoryId = slugify(category);
  const cityId = city && postalCode.length >= 3 ? `${postalCode}_${slugify(city)}` : null;
  const status = String(data.status ?? 'active').trim().toLowerCase();
  const isActive = typeof data.isActive === 'boolean' ? data.isActive : status === 'active';
  const dept = String(data.dept || '').trim() || departmentFromPostalCode(postalCode);
  const budgetValue = budgetValueFromAny(data.budgetValue ?? data.budget ?? data.price);

  const patch = {
    category,
    categoryId,
    city,
    location: city,
    cp: postalCode || null,
    postalCode: postalCode || null,
    cityId,
    cityCategoryKey: cityId ? `${cityId}_${categoryId}` : null,
    dept: dept || null,
    budgetValue,
    isActive,
    status: isActive ? 'active' : status || 'inactive',
  };

  const changed = {};
  for (const [k, v] of Object.entries(patch)) {
    const prev = Object.prototype.hasOwnProperty.call(data, k) ? data[k] : undefined;
    if (JSON.stringify(prev) !== JSON.stringify(v)) {
      changed[k] = v;
    }
  }

  return changed;
}

async function main() {
  const opts = parseArgs(process.argv);

  if (!admin.apps.length) {
    const init = opts.projectId ? { projectId: opts.projectId } : {};
    admin.initializeApp(init);
  }

  const db = admin.firestore();
  const snap = await db.collection('offers').orderBy('createdAt', 'desc').get();

  let scanned = 0;
  let toUpdate = 0;
  let updated = 0;
  let skipped = 0;

  let batch = db.batch();
  let batchCount = 0;
  const MAX_BATCH = 450;

  for (const doc of snap.docs) {
    if (opts.limit > 0 && scanned >= opts.limit) break;
    scanned++;

    const data = doc.data() || {};
    const patch = buildPatch(data);
    const keys = Object.keys(patch);

    if (keys.length === 0) {
      skipped++;
      continue;
    }

    toUpdate++;

    if (opts.dryRun) {
      console.log(`[dry-run] offers/${doc.id} -> ${keys.join(', ')}`);
      continue;
    }

    batch.update(doc.ref, patch);
    batchCount++;

    if (batchCount >= MAX_BATCH) {
      await batch.commit();
      updated += batchCount;
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (!opts.dryRun && batchCount > 0) {
    await batch.commit();
    updated += batchCount;
  }

  console.log('--- backfill summary ---');
  console.log(`scanned: ${scanned}`);
  console.log(`needs_update: ${toUpdate}`);
  console.log(`updated: ${opts.dryRun ? 0 : updated}`);
  console.log(`skipped: ${skipped}`);
  console.log(`mode: ${opts.dryRun ? 'dry-run' : 'apply'}`);
}

main().catch((err) => {
  console.error('[backfill_offer_indexes] failed:', err);
  process.exitCode = 1;
});
