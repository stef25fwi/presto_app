import assert from 'node:assert/strict';

const base = 'https://ilipresto.fr';

async function getText(url) {
  const response = await fetch(url, {
    headers: {'user-agent': 'ilipresto-structured-data-monitor/1.0'},
    redirect: 'follow',
  });
  assert.equal(response.status, 200, `${url}: HTTP ${response.status}`);
  return response.text();
}

function canonicalFor(route) {
  return route === '/' ? `${base}/` : `${base}${route}`;
}

function parseJsonLd(html, route) {
  const blocks = [...html.matchAll(/<script\s+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)];
  assert.ok(blocks.length > 0, `${route}: JSON-LD absent en production`);
  return blocks.map((match) => JSON.parse(match[1]));
}

function graphNodes(documents) {
  return documents.flatMap((document) => Array.isArray(document['@graph']) ? document['@graph'] : [document]);
}

function typesOf(node) {
  return Array.isArray(node['@type']) ? node['@type'] : [node['@type']].filter(Boolean);
}

const registryText = await getText(`${base}/structured-data-registry.json`);
const registry = JSON.parse(registryText);
assert.equal(registry.baseUrl, base, 'Registre de production: baseUrl incohérente');

for (const [route, config] of Object.entries(registry.staticRoutes)) {
  const html = await getText(canonicalFor(route));
  assert.ok(
    html.includes(`<link rel="canonical" href="${canonicalFor(route)}">`),
    `${route}: canonical absente en production`,
  );
  const nodes = graphNodes(parseJsonLd(html, route));
  const types = new Set(nodes.flatMap(typesOf));
  for (const required of config.requiredTypes) {
    assert.ok(types.has(required), `${route}: ${required} absent en production`);
  }
  for (const forbidden of registry.forbiddenTypes) {
    assert.ok(!types.has(forbidden), `${route}: ${forbidden} interdit en production`);
  }
}

for (const route of registry.dynamicLegalRoutes) {
  await getText(canonicalFor(route));
}

const legalSource = await getText(`${base}/public-route-seo.js`);
for (const route of registry.dynamicLegalRoutes) {
  assert.ok(legalSource.includes(`'${route}'`), `${route}: registre légal absent en production`);
}
for (const token of [
  "'@type': 'WebPage'",
  "'@type': 'BreadcrumbList'",
  "publisher: {'@id': organizationId}",
  "about: {'@id': organizationId}",
]) {
  assert.ok(legalSource.includes(token), `Production: ${token} absent du registre légal`);
}

console.log(`Production JSON-LD: ${Object.keys(registry.staticRoutes).length} pages statiques et ${registry.dynamicLegalRoutes.length} pages légales contrôlées.`);
