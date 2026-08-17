import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';

const registryPath = 'web/programmatic-seo-registry.json';
const originalRegistry = fs.readFileSync(registryPath, 'utf8');

function runGenerator() {
  const result = spawnSync(process.execPath, ['tools/seo/generate_programmatic_local_pages.mjs'], {
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, `Le générateur SEO a échoué:\n${result.stderr || result.stdout}`);
}

try {
  const registry = JSON.parse(originalRegistry);
  const city = registry.cities[0];
  const intent = registry.intents[0];
  const service = registry.services[0];

  city.postalCode = '97139';
  city.postalCodes = ['97139', '97142', '97180', '97139'];
  fs.writeFileSync(registryPath, `${JSON.stringify(registry, null, 2)}\n`);

  runGenerator();

  const pagePath = `web${intent.routePrefix}/${service.slug}/${city.slug}/index.html`;
  const html = fs.readFileSync(pagePath, 'utf8');
  assert.match(html, /97139 \+ 2 autres codes/, 'Le rendu doit résumer les codes postaux multiples sans duplication.');
  assert.doesNotMatch(html, /\[object Object\]/, 'Le rendu ne doit jamais exposer une sérialisation technique.');

  const descriptionMatch = html.match(/<meta name="description" content="([^"]+)">/);
  assert.ok(descriptionMatch, 'La meta description doit être présente.');
  assert.ok(descriptionMatch[1].length <= 180, `Meta description trop longue: ${descriptionMatch[1].length} caractères.`);

  console.log('Contrat multi-codes postaux: rendu compact, stable et compatible avec les limites SEO.');
} finally {
  fs.writeFileSync(registryPath, originalRegistry);
  runGenerator();
}
