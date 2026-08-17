import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const registry = JSON.parse(fs.readFileSync('web/programmatic-seo-registry.json', 'utf8'));
const signals = JSON.parse(fs.readFileSync('quality/seo-programmatic-local-signals.json', 'utf8'));
const sitemap = fs.readFileSync('web/sitemap-local.xml', 'utf8');
const expectedCount = registry.intents.length * registry.services.length * registry.cities.length;
const SAFE_PUBLIC_ID = /^[A-Za-z0-9_-]{6,128}$/;
const titles = new Set();
const canonicals = new Set();
let indexableCount = 0;
let indexableMissionCount = 0;
let indexableServiceCount = 0;

assert.equal(registry.version, 1, 'Version du registre SEO local inattendue');
assert.ok(registry.activationGate.minRealEntities >= 3, 'Seuil minRealEntities trop faible');
assert.ok(registry.activationGate.minRecentEntities >= 1, 'Seuil minRecentEntities trop faible');
assert.ok(registry.activationGate.maxSignalAgeHours > 0 && registry.activationGate.maxSignalAgeHours <= 72, 'Fraîcheur maximale des signaux invalide');
assert.ok(registry.activationGate.intentGates?.services?.minQualifiedProfiles >= 3, 'Seuil profils qualifiés trop faible');
assert.ok(registry.activationGate.intentGates?.services?.minRecentProfiles >= 1, 'Seuil profils récents trop faible');
assert.ok(registry.activationGate.intentGates?.missions?.minActiveListings >= 3, 'Seuil annonces actives trop faible');
assert.ok(registry.activationGate.intentGates?.missions?.minRecentListings >= 1, 'Seuil annonces récentes trop faible');
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

function signalsAreFresh() {
  const generatedMs = Date.parse(String(signals.generatedAt || ''));
  if (!Number.isFinite(generatedMs)) return false;
  const ageMs = Date.now() - generatedMs;
  return ageMs >= -5 * 60 * 1000
    && ageMs <= Number(registry.activationGate.maxSignalAgeHours) * 60 * 60 * 1000;
}

function readSignals(key) {
  const value = signals.pages?.[key] || {};
  const listingPreviews = Array.isArray(value.listingPreviews)
    ? value.listingPreviews.filter((item) =>
      SAFE_PUBLIC_ID.test(String(item?.id || ''))
      && String(item?.title || '').trim().length >= 12,
    ).slice(0, 5)
    : [];
  return {
    activeListings: Number(value.activeListings || 0),
    recentListings: Number(value.recentListings || 0),
    qualifiedProfiles: Number(value.qualifiedProfiles || 0),
    recentProfiles: Number(value.recentProfiles || 0),
    listingPreviews,
  };
}

function activationFor(intent, key, city) {
  const value = readSignals(key);
  const fresh = signalsAreFresh();
  const localIntroReady = !registry.activationGate.requireUniqueLocalIntro
    || String(city.localIntro || '').trim().length >= 60;
  if (!fresh || !localIntroReady) return {eligible: false, ...value};

  if (intent.key === 'services') {
    const gate = registry.activationGate.intentGates.services;
    return {
      eligible: value.qualifiedProfiles >= gate.minQualifiedProfiles
        && value.recentProfiles >= gate.minRecentProfiles,
      ...value,
    };
  }

  const gate = registry.activationGate.intentGates.missions;
  return {
    eligible: value.activeListings >= gate.minActiveListings
      && value.recentListings >= gate.minRecentListings
      && value.listingPreviews.length >= gate.minActiveListings,
    ...value,
  };
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
      const activation = activationFor(intent, keyFor(intent, service, city), city);

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

      if (activation.eligible) {
        indexableCount += 1;
        assert.ok(robots.startsWith('index,follow'), `${route}: page éligible non indexable`);
        assert.ok(sitemap.includes(`<loc>${canonical}</loc>`), `${route}: page indexable absente du sitemap local`);

        if (intent.key === 'missions') {
          indexableMissionCount += 1;
          assert.ok(
            activation.listingPreviews.length >= registry.activationGate.intentGates.missions.minActiveListings,
            `${route}: annonces réelles insuffisantes pour une page mission indexable`,
          );
          assert.ok(html.includes('aria-label="Annonces locales"'), `${route}: section annonces locales absente`);
          assert.ok(html.includes('/annonces/'), `${route}: liens vers annonces publiques absents`);
          assert.ok(html.includes('"@type":"ItemList"'), `${route}: ItemList des annonces absent`);
        } else {
          indexableServiceCount += 1;
          assert.ok(
            activation.qualifiedProfiles >= registry.activationGate.intentGates.services.minQualifiedProfiles,
            `${route}: profils qualifiés insuffisants pour une page service indexable`,
          );
        }
      } else {
        assert.equal(robots, 'noindex,follow', `${route}: page inactive doit rester noindex`);
        assert.ok(!sitemap.includes(`<loc>${canonical}</loc>`), `${route}: page noindex présente dans sitemap local`);
        if (intent.key === 'missions') {
          assert.ok(!html.includes('aria-label="Annonces locales"'), `${route}: annonces affichées sur une page mission inactive`);
        }
      }
    }
  }
}

assert.equal(visited, expectedCount, 'Nombre de pages locales contrôlées incohérent');
assert.equal(titles.size, expectedCount, 'Titles locaux non uniques');
assert.ok(!sitemap.includes('JobPosting'), 'JobPosting interdit dans le sitemap');

if (!signalsAreFresh()) {
  assert.equal(indexableCount, 0, 'Aucune page ne doit être indexable sans agrégat de production récent');
}

console.log(`SEO programmatique local: ${visited} pages validées, ${indexableCount} indexables (${indexableMissionCount} missions, ${indexableServiceCount} services).`);
