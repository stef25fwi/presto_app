import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');
const registry = JSON.parse(read('web/search-intent-registry.json'));
const sitemap = read('web/sitemap.xml');
const base = registry.baseUrl;

assert.equal(registry.guardrails.nationalPlatform, true, 'Positionnement national absent');
assert.equal(registry.guardrails.notAJobBoard, true, 'Distinction avec un site d’emploi absente');
assert.equal(registry.guardrails.noDoorwayPages, true, 'Garde-fou contre les pages satellites absent');

const implemented = registry.pillarPages.filter((page) => page.status === 'implemented');
assert.ok(implemented.length >= 3, 'Au moins trois pages piliers doivent être implémentées');

const titles = new Set();
const descriptions = new Set();
const h1s = new Set();
const forbiddenClaims = [
  /réponse garantie/i,
  /première place garantie/i,
  /des dizaines de (?:particuliers|professionnels|prestataires)/i,
  /réponse instantanée garantie/i,
];

const extract = (html, pattern, label) => {
  const match = html.match(pattern);
  assert.ok(match, `${label} absent`);
  return match[1].replace(/<[^>]+>/g, '').trim();
};

for (const page of implemented) {
  assert.ok(page.route.startsWith('/') && page.route.endsWith('/'), `${page.route}: route canonique invalide`);
  const file = `web${page.route}index.html`;
  assert.ok(fs.existsSync(file), `${page.route}: fichier statique absent`);
  const html = read(file);
  const canonical = `${base}${page.route}`;
  const title = extract(html, /<title>(.*?)<\/title>/s, `${page.route}: title`);
  const description = extract(html, /<meta name="description" content="(.*?)">/s, `${page.route}: description`);
  const h1 = extract(html, /<h1>(.*?)<\/h1>/s, `${page.route}: H1`);

  assert.ok(title.length >= 25 && title.length <= 70, `${page.route}: longueur du title`);
  assert.ok(description.length >= 110 && description.length <= 180, `${page.route}: longueur de description`);
  assert.ok(h1.length >= 20, `${page.route}: H1 trop court`);
  assert.ok(html.includes(`<link rel="canonical" href="${canonical}">`), `${page.route}: canonical incohérente`);

  if (page.sitemap === false) {
    assert.ok(!sitemap.includes(`<loc>${canonical}</loc>`), `${page.route}: URL régionale legacy ne doit pas être promue par le sitemap national`);
  } else {
    assert.ok(sitemap.includes(`<loc>${canonical}</loc>`), `${page.route}: URL absente du sitemap`);
  }

  assert.ok(html.includes('aria-label="Fil d’Ariane"'), `${page.route}: fil d’Ariane absent`);
  assert.ok((html.match(/<a href=/g) || []).length >= 7, `${page.route}: maillage interne insuffisant`);
  assert.ok(html.includes('alt="Logo iliprestō"'), `${page.route}: texte alternatif du logo absent`);
  forbiddenClaims.forEach((claim) => assert.ok(!claim.test(html), `${page.route}: promesse non vérifiée détectée`));

  assert.ok(!titles.has(title), `${page.route}: title dupliqué`);
  assert.ok(!descriptions.has(description), `${page.route}: description dupliquée`);
  assert.ok(!h1s.has(h1), `${page.route}: H1 dupliqué`);
  titles.add(title);
  descriptions.add(description);
  h1s.add(h1);
}

const demandPage = read('web/trouver-une-personne-disponible/index.html');
for (const concept of ['personne', 'compétente', 'disponible', 'service']) {
  assert.ok(demandPage.toLowerCase().includes(concept), `Page demandeur: concept ${concept} absent`);
}
assert.ok(demandPage.includes('petites annonces'), 'Page demandeur: positionnement petites annonces absent');
assert.ok(demandPage.includes('solution instantanée'), 'Page demandeur: notion de solution instantanée absente');
assert.ok(demandPage.includes('ne garantit pas'), 'Page demandeur: réserve sur le délai de réponse absente');

const overseasPage = read('web/services-outre-mer/index.html');
for (const territory of registry.territories) {
  assert.ok(overseasPage.includes(territory), `Hub Outre-mer: ${territory} absent`);
}
assert.ok(overseasPage.includes('site national'), 'Hub Outre-mer: rappel du positionnement national absent');
assert.ok(overseasPage.includes('petites annonces'), 'Hub Outre-mer: positionnement petites annonces absent');

const creationGuide = read('web/guides/creer-micro-entreprise-services/index.html');
assert.ok(creationGuide.includes('https://procedures.inpi.fr/'), 'Guide création: Guichet unique INPI absent');
assert.ok(creationGuide.includes('https://entreprendre.service-public.fr/'), 'Guide création: source Service-Public absente');
assert.ok(creationGuide.includes('Les règles fiscales, sociales et professionnelles peuvent évoluer'), 'Guide création: avertissement de vérification absent');

console.log(`Écosystème SEO: ${implemented.length} pages piliers implémentées et validées.`);
