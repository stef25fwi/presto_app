import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');
const registry = JSON.parse(read('web/search-intent-registry.json'));
const structuredDataRegistry = JSON.parse(read('web/structured-data-registry.json'));
const sitemap = read('web/sitemap.xml');
const base = registry.baseUrl;

assert.equal(registry.guardrails.nationalPlatform, true, 'Positionnement national absent');
assert.equal(registry.guardrails.notAJobBoard, true, 'Distinction avec un site d’emploi absente');
assert.equal(registry.guardrails.notAnEmployer, true, 'Distinction employeur absente');
assert.equal(registry.guardrails.noDoorwayPages, true, 'Garde-fou contre les pages satellites absent');
assert.equal(
  registry.guardrails.jobPostingStructuredDataForbiddenForServiceListings,
  true,
  'Garde-fou JobPosting absent',
);
assert.ok(
  structuredDataRegistry.forbiddenTypes.includes('JobPosting'),
  'JobPosting doit être interdit pour les pages de services',
);

const implemented = registry.pillarPages.filter((page) => page.status === 'implemented');
assert.ok(implemented.length >= 8, 'Au moins huit pages piliers doivent être implémentées');

const titles = new Set();
const descriptions = new Set();
const h1s = new Set();
const forbiddenClaims = [
  /réponse garantie/i,
  /première place garantie/i,
  /des dizaines de (?:particuliers|professionnels|prestataires)/i,
  /réponse instantanée garantie/i,
  /trouvez instantanément/i,
  /répondre immédiatement/i,
  /contact(?:er|é|és)? immédiatement/i,
  /solution instantanée/i,
  /à l’instant/i,
  /réponses immédiates/i,
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
const normalizedDemandPage = demandPage.toLowerCase();
for (const concept of ['personne', 'compétente', 'disponible', 'service']) {
  assert.ok(normalizedDemandPage.includes(concept), `Page demandeur: concept ${concept} absent`);
}
assert.ok(normalizedDemandPage.includes('petites annonces'), 'Page demandeur: positionnement petites annonces absent');
assert.ok(normalizedDemandPage.includes('ne garantit pas'), 'Page demandeur: réserve sur le délai de réponse absente');
assert.ok(!normalizedDemandPage.includes('trouvez instantanément'), 'Page demandeur: promesse instantanée interdite');
assert.ok(!normalizedDemandPage.includes('contacter immédiatement'), 'Page demandeur: promesse de contact immédiat interdite');

const servicesPage = read('web/services-et-microservices/index.html').toLowerCase();
for (const concept of ['services', 'micro-services', 'plateforme nationale', 'annonce assistée par ia', '0 % de commission']) {
  assert.ok(servicesPage.includes(concept), `Page services: concept ${concept} absent`);
}

const listingsPage = read('web/annonces-services/index.html').toLowerCase();
assert.ok(listingsPage.includes('annonces de services'), 'Page annonces: intention principale absente');
assert.ok(listingsPage.includes('annonce assistée par ia'), 'Page annonces: assistance IA absente');
assert.ok(listingsPage.includes('0 % de commission'), 'Page annonces: 0 % de commission absent');
assert.ok(listingsPage.includes('ne collecte ni ne gère les paiements'), 'Page annonces: rôle paiement absent');
assert.ok(listingsPage.includes('pages géographiques vides'), 'Page annonces: garde-fou doorway pages absent');

const individualsPage = read('web/services-entre-particuliers/index.html').toLowerCase();
assert.ok(individualsPage.includes('services entre particuliers'), 'Page particuliers: intention principale absente');
assert.ok(individualsPage.includes('n’est pas l’employeur'), 'Page particuliers: réserve employeur absente');

const providerPage = read('web/proposer-ses-services/index.html').toLowerCase();
assert.ok(providerPage.includes('proposez vos services'), 'Page prestataire: intention principale absente');
assert.ok(providerPage.includes('ne garantit pas l’obtention d’une mission'), 'Page prestataire: réserve mission absente');

const jobsPage = read('web/jobs-et-missions/index.html');
const normalizedJobsPage = jobsPage.toLowerCase();
for (const concept of ['petits jobs', 'missions de service', 'site d’offres d’emploi']) {
  assert.ok(normalizedJobsPage.includes(concept), `Page jobs: concept ${concept} absent`);
}
assert.ok(!jobsPage.includes('JobPosting'), 'Page jobs: JobPosting interdit pour les annonces de services');

const homePage = read('web/index.html').replace(/\s+/g, ' ').toLowerCase();
for (const concept of [
  'la solution à tout moment pour tous vos besoins du quotidien',
  'annonces assistées par ia',
  '0 % de commission',
  'ne collecte ni ne gère les paiements entre utilisateurs',
  'convenez directement des conditions de la mission',
]) {
  assert.ok(homePage.includes(concept), `Accueil: concept ${concept} absent`);
}

const usageGuide = read('web/guides/comment-fonctionne-ilipresto.html').toLowerCase();
for (const concept of ['annonce assistée par ia', '0 % de commission', 'échangez et convenez directement']) {
  assert.ok(usageGuide.includes(concept), `Guide d’utilisation: concept ${concept} absent`);
}

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

console.log(`Écosystème SEO acquisition: ${implemented.length} pages piliers implémentées et validées.`);
