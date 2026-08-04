import assert from 'node:assert/strict';
import fs from 'node:fs';

import { validateRuntimeSeoRegistry } from './runtime_seo_registry_contract.mjs';

const registrySource = fs.readFileSync('web/public-route-seo.js', 'utf8');
const legalRoutes = [
  '/mentions-legales',
  '/confidentialite',
  '/cgu',
  '/suppression-compte',
];

for (const routePath of legalRoutes) {
  const result = validateRuntimeSeoRegistry({
    registrySource,
    routePath,
    siteUrl: 'https://ilipresto.fr',
  });
  assert.deepEqual(result.errors, [], `${routePath}: ${result.errors.join(', ')}`);
  assert.equal(result.canonicalRegistered, true);
}

const missingRoute = validateRuntimeSeoRegistry({
  registrySource,
  routePath: '/route-absente',
  siteUrl: 'https://ilipresto.fr',
});
assert.equal(missingRoute.routeRegistered, false);
assert.ok(missingRoute.errors.includes('runtime_registry_route_missing'));

const wrongDomain = validateRuntimeSeoRegistry({
  registrySource,
  routePath: '/cgu',
  siteUrl: 'https://example.invalid',
});
assert.equal(wrongDomain.baseUrlRegistered, false);
assert.ok(wrongDomain.errors.includes('runtime_registry_base_url_mismatch'));

const missingCanonicalBuilder = validateRuntimeSeoRegistry({
  registrySource: registrySource.replace(
    'const canonical = baseUrl + path;',
    'const canonical = path;',
  ),
  routePath: '/cgu',
  siteUrl: 'https://ilipresto.fr',
});
assert.equal(missingCanonicalBuilder.canonicalBuilderRegistered, false);
assert.ok(
  missingCanonicalBuilder.errors.includes(
    'runtime_registry_canonical_builder_missing',
  ),
);

console.log('runtime_seo_registry_contract.test: OK');
