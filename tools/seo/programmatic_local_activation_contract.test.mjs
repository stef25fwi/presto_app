import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const signalsPath = 'quality/seo-programmatic-local-signals.json';
const generatorPath = 'tools/seo/generate_programmatic_local_pages.mjs';
const missionPath = 'web/missions/jardinage/les-abymes/index.html';
const servicePath = 'web/services/jardinage/les-abymes/index.html';
const sitemapPath = 'web/sitemap-local.xml';
const originalSignals = fs.readFileSync(signalsPath, 'utf8');

const previews = [
  {id: 'seo-test-a1', title: 'Entretien ponctuel d’un jardin aux Abymes', publishedAt: new Date().toISOString()},
  {id: 'seo-test-b2', title: 'Tonte et nettoyage d’un petit jardin', publishedAt: new Date().toISOString()},
  {id: 'seo-test-c3', title: 'Taille de haie et entretien extérieur', publishedAt: new Date().toISOString()},
];

const fixture = {
  version: 1,
  generatedAt: new Date().toISOString(),
  source: 'contract-test',
  pages: {
    'missions:jardinage:les-abymes': {
      activeListings: 3,
      recentListings: 1,
      qualifiedProfiles: 0,
      recentProfiles: 0,
      listingPreviews: previews,
    },
    'services:jardinage:les-abymes': {
      activeListings: 3,
      recentListings: 1,
      qualifiedProfiles: 0,
      recentProfiles: 0,
      listingPreviews: previews,
    },
  },
};

try {
  fs.writeFileSync(signalsPath, `${JSON.stringify(fixture, null, 2)}\n`);
  execFileSync(process.execPath, [generatorPath], {stdio: 'pipe'});

  const missionHtml = fs.readFileSync(missionPath, 'utf8');
  const serviceHtml = fs.readFileSync(servicePath, 'utf8');
  const sitemap = fs.readFileSync(sitemapPath, 'utf8');
  const missionCanonical = 'https://ilipresto.fr/missions/jardinage/les-abymes/';
  const serviceCanonical = 'https://ilipresto.fr/services/jardinage/les-abymes/';

  assert.match(missionHtml, /<meta name="robots" content="index,follow/);
  assert.ok(missionHtml.includes('aria-label="Annonces locales"'), 'La page mission active doit afficher les annonces locales');
  for (const preview of previews) {
    assert.ok(missionHtml.includes(`/annonces/${preview.id}/`), `Annonce ${preview.id} absente de la page mission`);
  }
  assert.ok(missionHtml.includes('"@type":"ItemList"'), 'ItemList des annonces locales absent');
  assert.ok(sitemap.includes(`<loc>${missionCanonical}</loc>`), 'Mission active absente du sitemap local');

  assert.ok(serviceHtml.includes('<meta name="robots" content="noindex,follow">'), 'Les annonces seules ne doivent jamais activer une page services');
  assert.ok(!sitemap.includes(`<loc>${serviceCanonical}</loc>`), 'Page services sans profils présente dans le sitemap local');

  console.log('Contrat activation SEO locale: annonces -> missions indexables, services sans profils -> noindex.');
} finally {
  fs.writeFileSync(signalsPath, originalSignals);
  execFileSync(process.execPath, [generatorPath], {stdio: 'pipe'});
}
