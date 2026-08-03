import assert from 'node:assert/strict';
import fs from 'node:fs';

const seoTitle = 'iliprestō – Trouvez un service près de chez vous';
const seoDescription =
  'Trouvez rapidement un particulier, un indépendant ou un professionnel partout en France. Publiez une annonce assistée par IA et échangez directement, avec 0 % de commission.';
const nationalLaunchMessage =
  'Plateforme nationale en cours de déploiement. Première ouverture en Guadeloupe, Martinique et Guyane.';
const legacyRegionalOnlyMessage =
  'Ouverture prochaine en Guadeloupe, Martinique et Guyane.';

const index = fs.readFileSync('web/index.html', 'utf8');
const service = fs.readFileSync(
  'lib/services/public_landing_config_service.dart',
  'utf8',
);
const webManifest = JSON.parse(fs.readFileSync('web/manifest.json', 'utf8'));
const docsManifest = JSON.parse(fs.readFileSync('docs/manifest.json', 'utf8'));

assert.ok(index.includes(`<title>${seoTitle}</title>`), 'title national absent');
assert.ok(
  index.includes(`<meta name="description" content="${seoDescription}">`),
  'meta description nationale absente',
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
  !index.includes(legacyRegionalOnlyMessage),
  'ancien message régional encore visible dans le HTML public',
);

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

assert.equal(webManifest.description, seoDescription);
assert.equal(docsManifest.description, seoDescription);

assert.ok(
  service.includes("'Plateforme nationale en cours de déploiement. Première ouverture en '"),
  'valeur nationale Flutter absente',
);
assert.ok(
  service.includes('if (_launchMessage == _legacyDefaultLaunchMessage)'),
  'migration de la valeur Remote Config historique absente',
);
assert.ok(
  service.includes('if (_legacyDefaultDescriptions.contains(_description))'),
  'migration des descriptions Remote Config historiques absente',
);

console.log('Positionnement national iliprestō validé.');
