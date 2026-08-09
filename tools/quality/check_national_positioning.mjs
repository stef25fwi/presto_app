import assert from 'node:assert/strict';
import fs from 'node:fs';

const seoTitle = 'iliprestō – Annonces assistées par IA, 0 % de commission';
const seoDescription =
  'La solution à tout moment pour vos besoins du quotidien : publiez une annonce assistée par IA, échangez directement et profitez de 0 % de commission.';
const nationalLaunchMessage =
  'Site national en cours de déploiement. Première ouverture en Guadeloupe, Martinique et Guyane.';
const legacyRegionalOnlyMessage =
  'Ouverture prochaine en Guadeloupe, Martinique et Guyane.';

const index = fs.readFileSync('web/index.html', 'utf8');
const normalizedIndex = index.replace(/\s+/g, ' ');
const service = fs.readFileSync(
  'lib/services/public_landing_config_service.dart',
  'utf8',
);
const webManifest = JSON.parse(fs.readFileSync('web/manifest.json', 'utf8'));
const docsManifest = JSON.parse(fs.readFileSync('docs/manifest.json', 'utf8'));

assert.ok(index.includes(`<title>${seoTitle}</title>`), 'title SEO absent');
assert.ok(
  index.includes(`<meta name="description" content="${seoDescription}">`),
  'meta description SEO absente',
);
assert.ok(
  index.includes(`<meta property="og:title" content="${seoTitle}">`),
  'Open Graph title non aligné',
);
assert.ok(
  index.includes(`<meta property="og:description" content="${seoDescription}">`),
  'Open Graph description non alignée',
);
assert.ok(
  index.includes(`<meta name="twitter:title" content="${seoTitle}">`),
  'Twitter title non aligné',
);
assert.ok(
  index.includes(`<meta name="twitter:description" content="${seoDescription}">`),
  'Twitter description non alignée',
);
assert.ok(index.includes(nationalLaunchMessage), 'message national visible absent');
assert.ok(
  index.includes('site de petites annonces de services et micro-services'),
  'positionnement petites annonces absent du HTML public',
);
assert.ok(
  normalizedIndex.includes('La solution à tout moment pour tous vos besoins du quotidien'),
  'positionnement à tout moment absent du HTML public',
);
assert.ok(
  normalizedIndex.includes('Annonces assistées par IA'),
  'annonces assistées par IA absentes du HTML public',
);
assert.ok(
  normalizedIndex.includes('ne collecte ni ne gère les paiements entre utilisateurs'),
  'rôle de non-intermédiaire de paiement absent du HTML public',
);
assert.ok(
  normalizedIndex.includes('Vous échangez et convenez directement des conditions de la mission'),
  'échange direct absent du HTML public',
);
assert.ok(
  !index.toLowerCase().includes('plateforme nationale de mise en relation'),
  'ancien positionnement de mise en relation encore présent dans le HTML public',
);
assert.ok(
  !index.includes(legacyRegionalOnlyMessage),
  'ancien message régional encore visible dans le HTML public',
);
for (const claim of [
  /solution instantanée/i,
  /trouvez instantanément/i,
  /à l’instant/i,
  /réponses immédiates/i,
  /contact(?:er|é|és)? immédiatement/i,
]) {
  assert.ok(!claim.test(index), `promesse non vérifiée encore présente: ${claim}`);
}

const jsonLdMatch = index.match(
  /<script\s+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/i,
);
assert.ok(jsonLdMatch, 'JSON-LD national absent');
const jsonLd = JSON.parse(jsonLdMatch[1]);
const nodes = Array.isArray(jsonLd['@graph']) ? jsonLd['@graph'] : [jsonLd];
const nationalAreas = nodes
  .map((node) => node?.areaServed)
  .filter(Boolean)
  .flatMap((area) => Array.isArray(area) ? area : [area]);
assert.ok(nationalAreas.length > 0, 'areaServed absent du JSON-LD');
assert.ok(
  nationalAreas.some(
    (area) => area?.['@type'] === 'Country' && area?.name === 'France',
  ),
  'Country France absent du JSON-LD',
);

const serviceNode = nodes.find((node) => node?.['@type'] === 'Service');
assert.ok(serviceNode, 'Service JSON-LD absent');
assert.equal(
  serviceNode.serviceType,
  'Site de petites annonces pour services et micro-services',
);
assert.ok(
  String(serviceNode.description || '').includes('annonce assistée par IA'),
  'annonce assistée par IA absente du Service JSON-LD',
);
assert.ok(
  String(serviceNode.description || '').includes('0 % de commission'),
  '0 % de commission absent du Service JSON-LD',
);
assert.ok(
  String(serviceNode.description || '').includes('sans paiement géré par iliprestō'),
  'rôle de non-intermédiaire de paiement absent du Service JSON-LD',
);

assert.equal(webManifest.description, seoDescription);
assert.equal(docsManifest.description, seoDescription);

assert.ok(
  service.includes("'Site national en cours de déploiement. Première ouverture en Guadeloupe, '"),
  'valeur nationale Flutter absente',
);
assert.ok(
  service.includes('if (_legacyDefaultLaunchMessages.contains(_launchMessage))'),
  'migration des messages Remote Config historiques absente',
);
assert.ok(
  service.includes('if (_legacyDefaultDescriptions.contains(_description))'),
  'migration des descriptions Remote Config historiques absente',
);
assert.ok(
  service.includes('if (_legacyDefaultTitles.contains(_title))'),
  'migration des titres Remote Config historiques absente',
);

console.log('Positionnement national IA, échange direct et 0 % de commission validé.');
