import assert from 'node:assert/strict';
import fs from 'node:fs';

const registry = JSON.parse(fs.readFileSync('web/programmatic-seo-registry.json', 'utf8'));
const constants = fs.readFileSync('lib/constants.dart', 'utf8');

const startMarker = 'const List<String> kCategories = [';
const start = constants.indexOf(startMarker);
assert.ok(start >= 0, 'kCategories absent de lib/constants.dart');
const end = constants.indexOf('];', start);
assert.ok(end > start, 'Fin de kCategories introuvable');

const categoryBlock = constants.slice(start + startMarker.length, end);
const appCategories = [...categoryBlock.matchAll(/^\s*'((?:\\'|[^'])*)',?\s*$/gm)]
  .map((match) => match[1].replaceAll("\\'", "'"));

assert.ok(appCategories.length >= 9, 'Taxonomie applicative trop courte');
assert.ok(appCategories.includes('Autre'), 'Catégorie de repli Autre absente de l’application');

const seoCategories = appCategories.filter((category) => category !== 'Autre');
const keys = new Set();
const slugs = new Set();
const taxonomyValues = new Set();

for (const service of registry.services) {
  assert.ok(service.key && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(service.key), `${service.serviceTitle}: key invalide`);
  assert.ok(service.slug && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(service.slug), `${service.serviceTitle}: slug invalide`);
  assert.ok(!keys.has(service.key), `${service.serviceTitle}: key dupliquée`);
  assert.ok(!slugs.has(service.slug), `${service.serviceTitle}: slug dupliqué`);
  assert.ok(!taxonomyValues.has(service.taxonomyValue), `${service.serviceTitle}: taxonomie dupliquée`);
  assert.ok(appCategories.includes(service.taxonomyValue), `${service.serviceTitle}: taxonomyValue absent de kCategories`);
  assert.notEqual(service.taxonomyValue, 'Autre', 'La catégorie Autre ne doit pas générer de pages SEO programmatiques');
  assert.ok(Array.isArray(service.keywords) && service.keywords.length >= 4, `${service.serviceTitle}: mots-clés insuffisants`);
  keys.add(service.key);
  slugs.add(service.slug);
  taxonomyValues.add(service.taxonomyValue);
}

for (const category of seoCategories) {
  assert.ok(taxonomyValues.has(category), `Catégorie applicative non couverte par le SEO programmatique: ${category}`);
}

assert.equal(registry.services.length, seoCategories.length, 'Le registre SEO doit couvrir chaque catégorie applicative sauf Autre exactement une fois');
console.log(`Taxonomie SEO: ${registry.services.length} catégories validées contre kCategories (Autre exclue).`);
