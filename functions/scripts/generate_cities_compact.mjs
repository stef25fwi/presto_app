#!/usr/bin/env node
/**
 * Régénère assets/data/cities_compact.json depuis geo.api.gouv.fr.
 *
 * geo.api.gouv.fr est la source de vérité officielle : noms avec accents,
 * codes postaux à jour, codes département et région certifiés.
 *
 * Usage :
 *   node functions/scripts/generate_cities_compact.mjs
 *   node functions/scripts/generate_cities_compact.mjs --out=assets/data/cities_compact.json
 *   node functions/scripts/generate_cities_compact.mjs --dry-run   # affiche stats sans écrire
 *
 * Après génération, relancer le seed Firestore :
 *   cd functions && npx ts-node scripts/seedMarketplaceTaxonomy.ts --apply
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');

const GEO_API_BASE = 'https://geo.api.gouv.fr';
const FIELDS = 'nom,codesPostaux,codeDepartement,codeRegion';

// Tous les codes département métropole + DOM (pas les COM : 977, 978, 984, 986, 987, 988
// car leur couverture est partielle sur l'API communes).
const DEPARTMENT_CODES = [
  '01','02','03','04','05','06','07','08','09',
  '10','11','12','13','14','15','16','17','18','19',
  '2A','2B',
  '21','22','23','24','25','26','27','28','29',
  '30','31','32','33','34','35','36','37','38','39',
  '40','41','42','43','44','45','46','47','48','49',
  '50','51','52','53','54','55','56','57','58','59',
  '60','61','62','63','64','65','66','67','68','69',
  '70','71','72','73','74','75','76','77','78','79',
  '80','81','82','83','84','85','86','87','88','89',
  '90','91','92','93','94','95',
  '971','972','973','974','976',
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Appelle l'API avec retry exponentiel.
 * @param {string} url
 * @param {number} maxRetries
 * @returns {Promise<unknown>}
 */
async function fetchJson(url, maxRetries = 4) {
  let delay = 1000;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    let resp;
    try {
      resp = await fetch(url, { signal: AbortSignal.timeout(15_000) });
    } catch (err) {
      if (attempt === maxRetries) throw err;
      process.stderr.write(`    [retry ${attempt}/${maxRetries}] réseau: ${err.message}\n`);
      await sleep(delay);
      delay *= 2;
      continue;
    }

    if (resp.status === 429 || resp.status >= 500) {
      if (attempt === maxRetries) throw new Error(`HTTP ${resp.status} sur ${url}`);
      process.stderr.write(`    [retry ${attempt}/${maxRetries}] HTTP ${resp.status}\n`);
      await sleep(delay);
      delay *= 2;
      continue;
    }

    if (!resp.ok) {
      throw new Error(`HTTP ${resp.status} sur ${url}`);
    }

    return await resp.json();
  }
}

/**
 * Récupère toutes les communes d'un département.
 * @param {string} dept
 * @returns {Promise<Array<{name: string, dept: string, cps: string[], region: string}>>}
 */
async function fetchDept(dept) {
  const url = `${GEO_API_BASE}/communes?codeDepartement=${encodeURIComponent(dept)}&fields=${FIELDS}&format=json`;
  const raw = await fetchJson(url);

  if (!Array.isArray(raw)) return [];

  const entries = [];
  for (const commune of raw) {
    const name = String(commune.nom || '').trim();
    if (!name) continue;

    const cps = Array.isArray(commune.codesPostaux)
      ? commune.codesPostaux
          .map((cp) => String(cp).trim())
          .filter((cp) => /^\d{4,6}$/.test(cp))
      : [];
    if (cps.length === 0) continue;

    const deptCode = String(commune.codeDepartement || dept).trim();
    const region = String(commune.codeRegion || '').trim();

    entries.push({ name, dept: deptCode, cps, region });
  }

  return entries;
}

function parseArgs(argv) {
  const opts = { dryRun: false, outPath: null, delayMs: 60 };
  for (const arg of argv.slice(2)) {
    if (arg === '--dry-run') { opts.dryRun = true; continue; }
    if (arg.startsWith('--out=')) { opts.outPath = path.resolve(arg.slice('--out='.length)); continue; }
    if (arg.startsWith('--delay=')) { opts.delayMs = Number(arg.slice('--delay='.length)) || 60; continue; }
  }
  if (!opts.outPath) {
    opts.outPath = path.join(REPO_ROOT, 'assets', 'data', 'cities_compact.json');
  }
  return opts;
}

async function main() {
  const opts = parseArgs(process.argv);

  console.log('=== generate_cities_compact.mjs ===');
  console.log(`Source     : ${GEO_API_BASE}/communes`);
  console.log(`Destination: ${opts.outPath}`);
  console.log(`Mode       : ${opts.dryRun ? 'DRY-RUN (pas d\'écriture)' : 'ÉCRITURE'}`);
  console.log(`Délai API  : ${opts.delayMs}ms entre départements`);
  console.log('');

  const allEntries = [];
  // Déduplication par (CP principal, département) pour éviter les doublons
  // en cas de communes à cheval sur plusieurs départements.
  const seen = new Set();
  let skipped = 0;

  for (let i = 0; i < DEPARTMENT_CODES.length; i++) {
    const dept = DEPARTMENT_CODES[i];
    const progress = `[${String(i + 1).padStart(2)}/${DEPARTMENT_CODES.length}]`;
    process.stdout.write(`${progress} dept ${dept.padEnd(3)} ... `);

    let entries;
    try {
      entries = await fetchDept(dept);
    } catch (err) {
      process.stdout.write(`ERREUR: ${err.message}\n`);
      entries = [];
    }

    let added = 0;
    for (const entry of entries) {
      const key = `${entry.cps[0]}|${entry.dept}`;
      if (seen.has(key)) { skipped++; continue; }
      seen.add(key);
      allEntries.push(entry);
      added++;
    }

    process.stdout.write(`${entries.length} communes, ${added} ajoutées\n`);

    if (i < DEPARTMENT_CODES.length - 1) {
      await sleep(opts.delayMs);
    }
  }

  // Trier par nom (locale française) pour des diffs lisibles
  allEntries.sort((a, b) => a.name.localeCompare(b.name, 'fr', { sensitivity: 'base' }));

  // Supprimer le champ region vide pour garder le JSON compact
  const compact = allEntries.map(({ name, dept, cps, region }) => {
    const entry = { name, dept, cps };
    if (region) entry.region = region;
    return entry;
  });

  console.log('');
  console.log(`Total communes : ${compact.length}`);
  console.log(`Doublons ignorés : ${skipped}`);

  if (opts.dryRun) {
    console.log('Dry-run : fichier non écrit.');
    return;
  }

  await fs.mkdir(path.dirname(opts.outPath), { recursive: true });
  await fs.writeFile(opts.outPath, JSON.stringify(compact, null, 2) + '\n', 'utf8');
  const stat = await fs.stat(opts.outPath);
  console.log(`Écrit : ${opts.outPath} (${(stat.size / 1024).toFixed(1)} Ko)`);
  console.log('');
  console.log('Étape suivante — reseed Firestore :');
  console.log('  cd functions && npx ts-node scripts/seedMarketplaceTaxonomy.ts --apply');
}

main().catch((err) => {
  console.error('[generate_cities_compact] échec :', err);
  process.exitCode = 1;
});
