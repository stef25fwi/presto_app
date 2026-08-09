import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const registry = JSON.parse(fs.readFileSync('web/programmatic-seo-registry.json', 'utf8'));
const signals = JSON.parse(fs.readFileSync('quality/seo-programmatic-local-signals.json', 'utf8'));
const sitemap = fs.readFileSync('web/sitemap-local.xml', 'utf8');
const expectedCount = registry.intents.length * registry.services.length * registry.cities.length;
const titles = new Set();
const canonicals = new Set();
let indexableCount = 0;

assert.equal(registry.version, 1, 'Version du registre SEO local inattendue');
assert.ok(registry.activationGate.minRealEntities >= 3, 'Seuil minRealEntities trop faible');
assert.ok(registry.activationGate.minRecentEntities >= 1, 'Seuil minRecentEntities trop faible');
assert.equal(registry.activationGate.inactiveRobots, 'noindex,follow', 'Robots des pages inactives incorrect');
assert.ok(registry.intents.some((item) => item.key === 'services'), 'Intention services absente');
assert.ok(registry.intents.some((item) => item.key === 'missions'), 'Intention missions absente');
assert.ok(registry.cities.some((item) => item.territory === 'Guadeloupe'), 'Pilote Guadeloupe absent');
assert.ok(registry.cities.some((item) => item.territory === 'Martinique'), 'Pilote Martinique absent');
assert.ok(registry.cities.some((item) => item.territory === 'Guyane'), 'Pilote Guyane absent');

function keyFor(intent, service, city) {
  return `${intent.key}:${service.key}:${city.slug}`;
}

function routeFor(intent, service, city) {
  return `${intent.routePrefix}/${service.slug}/${city.slug}/`;
}

function activationFor(key, city) {
  const value = signals.pages?.[key] || {};
  const activeListings = Number(value.activeListings || 0);
  const qualifiedProfiles = Number(value.qualifiedProfiles || 0);
  const recentListings = Number(value.recentListings || 0);
  const recentProfiles = Number(value.recentProfiles || 0);
  const realEntities = activeListings + qualifiedProfiles;
  const recentEntities = recentListings + recentProfiles;
  return realEntities >= registry.activationGate.minRealEntities
    && recentEntities >= registry.activationGate.minRecentEntities
    && String(city.localIntro || '').trim().length >= 60;
}

let visited = 0;
for (const intent of registry.intents) {
  for (const service of registry.services) {
    for (const city of registry.cities) {
      visited += 1;
      const route = routeFor(intent, service, city);
      const file = path.join('web', route.replace(/^\//, ''), 'index.html');
      assert.ok(fs.existsSync(file), `${route}: page générée absente`);
      const html = fs.readFileSync(file, 'utf8');
      const canonical = `${registry.baseUrl}${route}`;
      const title = html.match(/<title>(.*?)<\/title>/s)?.[1]?.trim();
      const description = html.match(/<meta name="description" content="(.*?)">/s)?.[1]?.trim();
      const robots = html.match(/<meta name="robots" content="(.*?)">/s)?.[1]?.trim();
      const eligible = activationFor(keyFor(intent, service, city), city);

      assert.ok(title && title.length >= 25 && title.length <= 70, `${route}: title invalide`);
      assert.ok(description && description.length >= 110 && description.length <= 180, `${route}: description invalide`);
      assert.ok(html.includes(`<link rel="canonical" href="${canonical}">`), `${route}: canonical absente`);
      assert.ok(html.includes('aria-label="Fil d’Ariane"'), `${route}: fil d’Ariane absent`);
      assert.ok(html.includes('"@type":"Service"'), `${route}: Service JSON-LD absent`);
      assert.ok(html.includes('"@type":"BreadcrumbList"'), `${route}: BreadcrumbList absent`);
      assert.ok(!/"@type"\s*:\s*"JobPosting"/.test(html), `${route}: JobPosting interdit`);
      assert.ok(!/réponse garantie|revenu garanti|mission garantie/i.test(html), `${route}: promesse interdite`);
      assert.ok((html.match(/<a href=/g) || []).length >= 8, `${route}: maillage interne insuffisant`);
      assert.ok(!titles.has(title), `${route}: title dupliqué`);
      assert.ok(!canonicals.has(canonical), `${route}: canonical dupliquée`);
      titles.add(title);
      canonicals.add(canonical);

      if (eligible) {
        indexableCount += 1;
        assert.ok(robots.startsWith('index,follow'), `${route}: page éligible non indexable`);
        assert.ok(sitemap.includes(`<loc>${canonical}</loc>`), `${route}: page indexable absente du sitemap local`);
      } else {
        assert.equal(robots, 'noindex,follow', `${route}: page inactive doit rester noindex`);
        assert.ok(!sitemap.includes(`<loc>${canonical}</loc>`), `${route}: page noindex présente dans sitemap local`);
      }
    }
  }
}

assert.equal(visited, expectedCount, 'Nombre de pages locales contrôlées incohérent');
assert.equal(titles.size, expectedCount, 'Titles locaux non uniques');
assert.ok(!sitemap.includes('JobPosting'), 'JobPosting interdit dans le sitemap');

if (!signals.generatedAt) {
  assert.equal(indexableCount, 0, 'Aucune page ne doit être indexable sans agrégat de production daté');
}

console.log(`SEO programmatique local: ${visited} pages validées, ${indexableCount} indexables.`);
