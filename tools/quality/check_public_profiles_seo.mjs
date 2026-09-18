import assert from 'node:assert/strict';
import fs from 'node:fs';

const ui = fs.readFileSync('lib/pages/pro_profile_page.dart', 'utf8');
const projection = fs.readFileSync('functions/src/modules/pro/public_profile_projection.ts', 'utf8');
const core = fs.readFileSync('functions/src/modules/seo/public_profiles_core.ts', 'utf8');
const handler = fs.readFileSync('functions/src/modules/seo/public_profiles.ts', 'utf8');
const collector = fs.readFileSync('functions/scripts/generate_programmatic_seo_signals.mjs', 'utf8');
const generator = fs.readFileSync('tools/seo/generate_programmatic_local_pages.mjs', 'utf8');
const index = fs.readFileSync('functions/src/index.ts', 'utf8');
const firebase = JSON.parse(fs.readFileSync('firebase.json', 'utf8'));
const robots = fs.readFileSync('web/robots.txt', 'utf8');

assert.ok(ui.includes("'seoPublicProfileConsent': _seoPublicProfileConsent"), 'Consentement SEO profil non persisté');
assert.ok(ui.includes('seoPublicProfileConsentVersion'), 'Version du consentement SEO absente');
assert.ok(ui.includes('Le SIRET, l’adresse complète, l’e-mail et le téléphone restent privés.'), 'Information de confidentialité du consentement absente');

assert.ok(projection.includes('onDocumentWritten'), 'Trigger de projection profil public absent');
assert.ok(projection.includes('"pro_profiles/{uid}"'), 'Source pro_profiles absente');
assert.ok(projection.includes('"public_service_profiles"'), 'Collection publique séparée absente');
assert.ok(projection.includes('sourceProfileIsPublicEligible'), 'Gate de consentement/éligibilité absent');

assert.ok(core.includes('seoPublicProfileConsent === true'), 'Consentement explicite non exigé');
assert.ok(core.includes('siretVerified === true'), 'SIRET vérifié non exigé');
assert.ok(core.includes('createHash("sha256")'), 'ID public découplé du Firebase UID absent');
assert.ok(core.includes('"@type": "ProfilePage"'), 'ProfilePage JSON-LD absent');
assert.ok(!core.includes('contactEmail:'), 'Email interdit dans la projection publique');
assert.ok(!core.includes('contactPhone:'), 'Téléphone interdit dans la projection publique');
assert.ok(!core.includes('siret:'), 'SIRET interdit dans la projection publique');
assert.ok(!core.includes('address:'), 'Adresse complète interdite dans la projection publique');
assert.ok(!core.includes('JobPosting'), 'JobPosting interdit sur les profils publics');

assert.ok(handler.includes('minInstances: 0'), 'Function profils publics doit rester à minInstances 0');
assert.ok(handler.includes('sitemap-prestataires.xml'), 'Sitemap profils absent du handler');
assert.ok(handler.includes('public_service_profiles'), 'Handler non relié à la projection publique');

assert.ok(index.includes('onProProfilePublicProjection'), 'Export du trigger projection absent');
assert.ok(index.includes('publicProfilesSeo'), 'Export SSR profils absent');

assert.ok(collector.includes("db.collection('public_service_profiles')"), 'Collecteur local ne lit pas les profils publics');
assert.ok(collector.includes('qualifiedProfiles: bucket.qualifiedProfiles'), 'Profils qualifiés encore désactivés dans les signaux');
assert.ok(collector.includes('recentProfiles: bucket.recentProfiles'), 'Profils récents encore désactivés dans les signaux');
assert.ok(collector.includes('profilePreviews: bucket.profilePreviews'), 'Prévisualisations profils absentes des signaux');

assert.ok(generator.includes('aria-label="Prestataires locaux"'), 'Section profils locaux absente des pages services');
assert.ok(generator.includes('/prestataires/'), 'Liens vers profils publics absents des pages services');
assert.ok(generator.includes('value.profilePreviews.length >= minQualifiedProfiles'), 'Activation service non liée aux profils rendus');

for (const target of ['production', 'mirror']) {
  const hosting = firebase.hosting.find((entry) => entry.target === target);
  assert.ok(hosting, `Hosting target ${target} absent`);
  const rewrites = hosting.rewrites || [];
  const catchAll = rewrites.findIndex((entry) => entry.source === '**');
  assert.ok(catchAll >= 0, `${target}: catch-all Flutter absent`);
  for (const source of ['/sitemap-prestataires.xml', '/prestataires/**']) {
    const indexRoute = rewrites.findIndex((entry) => entry.source === source);
    assert.ok(indexRoute >= 0, `${target}: rewrite ${source} absent`);
    assert.ok(indexRoute < catchAll, `${target}: rewrite ${source} doit précéder le catch-all`);
    assert.equal(rewrites[indexRoute].function?.functionId, 'publicProfilesSeo', `${target}: functionId profil incorrect`);
    assert.equal(rewrites[indexRoute].function?.region, 'europe-west1', `${target}: région profil incorrecte`);
  }
}

assert.ok(
  robots.includes('Sitemap: https://ilipresto.fr/sitemap-prestataires.xml'),
  'Sitemap prestataires absent de robots.txt',
);

console.log('SEO profils publics: consentement, confidentialité, SSR, sitemap et activation locale validés.');
