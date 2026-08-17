import assert from 'node:assert/strict';
import fs from 'node:fs';

const registry = JSON.parse(fs.readFileSync('web/programmatic-seo-registry.json', 'utf8'));
const citySource = JSON.parse(fs.readFileSync('assets/data/cities_compact.json', 'utf8'));

assert.ok(Array.isArray(citySource), 'cities_compact.json doit être une liste');
assert.ok(citySource.length > 1000, 'La source géographique nationale semble incomplète');

function normalize(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[’']/g, '')
    .replace(/[^a-z0-9]+/g, '');
}

const rows = citySource
  .filter((row) => row && typeof row === 'object')
  .map((row) => ({
    name: String(row.name || '').trim(),
    normalizedName: normalize(row.name),
    dept: String(row.dept || '').trim(),
    region: String(row.region || '').trim(),
    cps: Array.isArray(row.cps) ? row.cps.map((value) => String(value).trim()).filter(Boolean) : [],
  }))
  .filter((row) => row.name && row.cps.length > 0);

assert.ok(rows.length > 1000, 'La source géographique nationale ne contient pas assez de villes valides');

const slugs = new Set();
for (const city of registry.cities) {
  assert.ok(city.slug && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(city.slug), `${city.name}: slug SEO invalide`);
  assert.ok(!slugs.has(city.slug), `${city.name}: slug SEO dupliqué`);
  slugs.add(city.slug);

  const requestedCodes = new Set([
    String(city.postalCode || '').trim(),
    ...(Array.isArray(city.postalCodes) ? city.postalCodes.map((value) => String(value).trim()) : []),
  ].filter(Boolean));
  assert.ok(requestedCodes.size > 0, `${city.name}: aucun code postal déclaré`);
  for (const cp of requestedCodes) {
    assert.match(cp, /^\d{5}$/, `${city.name}: code postal invalide ${cp}`);
  }

  const normalizedName = normalize(city.sourceName || city.name);
  const candidates = rows.filter((row) => row.normalizedName === normalizedName);
  assert.ok(candidates.length > 0, `${city.name}: ville absente de cities_compact.json`);

  const availableCodes = new Set(candidates.flatMap((row) => row.cps));
  for (const cp of requestedCodes) {
    assert.ok(availableCodes.has(cp), `${city.name}: code postal ${cp} absent de cities_compact.json`);
  }

  if (city.departmentCode) {
    assert.ok(candidates.some((row) => row.dept === String(city.departmentCode)), `${city.name}: département incohérent`);
  }
  if (city.regionCode) {
    assert.ok(candidates.some((row) => row.region === String(city.regionCode)), `${city.name}: région incohérente`);
  }
}

console.log(`Source géographique SEO: ${registry.cities.length} villes validées contre ${rows.length} villes de cities_compact.json.`);
