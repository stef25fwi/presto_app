import assert from 'node:assert/strict';
import fs from 'node:fs';

const firebase = JSON.parse(fs.readFileSync('firebase.json', 'utf8'));
const robots = fs.readFileSync('web/robots.txt', 'utf8');
const indexSource = fs.readFileSync('functions/src/index.ts', 'utf8');
const rendererSource = fs.readFileSync('functions/src/modules/seo/public_marketplace_core.ts', 'utf8');
const handlerSource = fs.readFileSync('functions/src/modules/seo/public_marketplace.ts', 'utf8');

const expectedRoutes = ['/sitemap-annonces.xml', '/annonces/**'];
for (const target of ['production', 'mirror']) {
  const hosting = firebase.hosting.find((entry) => entry.target === target);
  assert.ok(hosting, `Hosting target ${target} absent`);
  const rewrites = hosting.rewrites || [];
  const catchAllIndex = rewrites.findIndex((entry) => entry.source === '**');
  assert.ok(catchAllIndex >= 0, `${target}: catch-all Flutter absent`);

  for (const source of expectedRoutes) {
    const routeIndex = rewrites.findIndex((entry) => entry.source === source);
    assert.ok(routeIndex >= 0, `${target}: rewrite ${source} absent`);
    assert.ok(routeIndex < catchAllIndex, `${target}: rewrite ${source} doit précéder le catch-all`);
    const route = rewrites[routeIndex];
    assert.equal(route.function?.functionId, 'publicMarketplaceSeo', `${target}: functionId incorrect pour ${source}`);
    assert.equal(route.function?.region, 'europe-west1', `${target}: région incorrecte pour ${source}`);
  }
}

assert.ok(
  robots.includes('Sitemap: https://ilipresto.fr/sitemap-annonces.xml'),
  'Sitemap annonces absent de robots.txt',
);
assert.ok(
  indexSource.includes('export { publicMarketplaceSeo } from "./modules/seo/public_marketplace";'),
  'Export publicMarketplaceSeo absent',
);
assert.ok(handlerSource.includes('minInstances: 0'), 'La Function SEO doit rester à minInstances 0');
assert.ok(handlerSource.includes('.where("status", "==", "active")'), 'Filtre status public absent');
assert.ok(handlerSource.includes('.where("visibility", "==", "public")'), 'Filtre visibility public absent');
assert.ok(handlerSource.includes('.select(...PUBLIC_LISTING_FIELDS)'), 'Projection Firestore SEO absente');
assert.ok(!rendererSource.includes('JobPosting'), 'JobPosting interdit dans le rendu des annonces de services');
assert.ok(!rendererSource.includes('phone:'), 'Téléphone interdit dans la projection SEO publique');
assert.ok(!rendererSource.includes('email:'), 'Email interdit dans la projection SEO publique');
assert.ok(!rendererSource.includes('ownerId:'), 'ownerId interdit dans la projection SEO publique');
assert.ok(rendererSource.includes('0 % de commission'), 'Promesse 0 % de commission absente du rendu public');
assert.ok(
  rendererSource.includes('ne collecte ni ne gère les paiements entre utilisateurs'),
  'Rôle de non-intermédiaire de paiement absent du rendu public',
);
assert.ok(
  rendererSource.includes('convenez directement des conditions de la mission'),
  'Échange direct absent du rendu public',
);

console.log('SEO annonces publiques: routage, confidentialité et sitemap validés.');
