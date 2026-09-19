import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const signalsPath = 'quality/seo-programmatic-local-signals.json';
const generatorPath = 'tools/seo/generate_programmatic_local_pages.mjs';
const missionPath = 'web/missions/jardinage/les-abymes/index.html';
const servicePath = 'web/services/jardinage/les-abymes/index.html';
const sitemapPath = 'web/sitemap-local.xml';
const originalSignals = fs.readFileSync(signalsPath, 'utf8');

function publicSlug(value, fallback) {
  const slug = String(value || '')
    .trim()
    .toLowerCase()
    .replaceAll('œ', 'oe')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[’']/g, '-')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 72)
    .replace(/-$/g, '');
  return slug.length >= 3 ? slug : fallback;
}

const previews = [
  {id: 'seo-test-a1', title: 'Entretien ponctuel d’un jardin aux Abymes', publishedAt: new Date().toISOString()},
  {id: 'seo-test-b2', title: 'Tonte et nettoyage d’un petit jardin', publishedAt: new Date().toISOString()},
  {id: 'seo-test-c3', title: 'Taille de haie et entretien extérieur', publishedAt: new Date().toISOString()},
];

const profilePreviews = [
  {publicId: 'aaaaaaaaaaaaaaaaaaaaaaaa', companyName: 'Jardin Soleil', activity: 'Jardinage', updatedAt: new Date().toISOString()},
  {publicId: 'bbbbbbbbbbbbbbbbbbbbbbbb', companyName: 'Vert Caraïbes', activity: 'Entretien de jardins', updatedAt: new Date().toISOString()},
  {publicId: 'cccccccccccccccccccccccc', companyName: 'Services Tropicaux', activity: 'Jardinage et débroussaillage', updatedAt: new Date().toISOString()},
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
      qualifiedProfiles: 3,
      recentProfiles: 1,
      listingPreviews: previews,
      profilePreviews,
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
    assert.ok(missionHtml.includes(`/annonces/${publicSlug(preview.title, 'annonce')}/${preview.id}/`), `Annonce ${preview.id} absente de la page mission`);
  }
  assert.ok(missionHtml.includes('"@type":"ItemList"'), 'ItemList des annonces locales absent');
  assert.ok(sitemap.includes(`<loc>${missionCanonical}</loc>`), 'Mission active absente du sitemap local');

  assert.match(serviceHtml, /<meta name="robots" content="index,follow/);
  assert.ok(serviceHtml.includes('aria-label="Prestataires locaux"'), 'La page service active doit afficher les profils publics');
  for (const profile of profilePreviews) {
    assert.ok(serviceHtml.includes(`/prestataires/${publicSlug(profile.companyName, 'prestataire')}/${profile.publicId}/`), `Profil ${profile.publicId} absent de la page service`);
  }
  assert.ok(serviceHtml.includes('"@type":"ItemList"'), 'ItemList des prestataires absent');
  assert.ok(sitemap.includes(`<loc>${serviceCanonical}</loc>`), 'Service actif absent du sitemap local');

  console.log('Contrat activation SEO locale: annonces -> missions indexables, profils publics -> services indexables.');
} finally {
  fs.writeFileSync(signalsPath, originalSignals);
  execFileSync(process.execPath, [generatorPath], {stdio: 'pipe'});
}
