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
assert.ok(index.includes('"areaServed"'), 'areaServed absent du JSON-LD');
assert.ok(index.includes('"@type": "Country"'), 'Country absent du JSON-LD');
assert.ok(index.includes('"name": "France"'), 'France absente du JSON-LD');
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
  service.includes('if (_description == _legacyDefaultDescription)'),
  'migration de la description Remote Config historique absente',
);

console.log('Positionnement national iliprestō validé.');
