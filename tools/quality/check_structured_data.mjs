import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');
const registry = JSON.parse(read('web/structured-data-registry.json'));
const base = registry.baseUrl;

function canonicalFor(route) {
  return route === '/' ? `${base}/` : `${base}${route}`;
}

function parseJsonLd(html, file) {
  const blocks = [...html.matchAll(/<script\s+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)];
  assert.ok(blocks.length > 0, `${file}: aucun bloc JSON-LD`);
  return blocks.map((match, index) => {
    try {
      return JSON.parse(match[1]);
    } catch (error) {
      throw new Error(`${file}: JSON-LD ${index + 1} invalide: ${error.message}`);
    }
  });
}

function graphNodes(documents) {
  return documents.flatMap((document) => {
    if (Array.isArray(document)) return document;
    if (Array.isArray(document['@graph'])) return document['@graph'];
    return [document];
  });
}

function nodeTypes(node) {
  const value = node?.['@type'];
  if (Array.isArray(value)) return value;
  return value ? [value] : [];
}

function findType(nodes, type) {
  return nodes.find((node) => nodeTypes(node).includes(type));
}

function assertHttpsUrl(value, label) {
  assert.equal(typeof value, 'string', `${label}: URL absente`);
  assert.ok(value.startsWith('https://'), `${label}: URL non HTTPS`);
}

function assertIsoDate(value, label) {
  assert.equal(typeof value, 'string', `${label}: date absente`);
  assert.ok(!Number.isNaN(Date.parse(value)), `${label}: date ISO 8601 invalide`);
}

function validateBreadcrumb(node, route) {
  const items = node.itemListElement;
  assert.ok(Array.isArray(items) && items.length >= 2, `${route}: fil d’Ariane incomplet`);
  const urls = new Set();
  items.forEach((item, index) => {
    assert.ok(nodeTypes(item).includes('ListItem'), `${route}: élément de fil invalide`);
    assert.equal(item.position, index + 1, `${route}: positions de fil non séquentielles`);
    assert.equal(typeof item.name, 'string', `${route}: nom de fil absent`);
    assertHttpsUrl(item.item, `${route}: item du fil`);
    assert.ok(item.item.startsWith(base), `${route}: fil hors domaine`);
    assert.ok(!urls.has(item.item), `${route}: URL dupliquée dans le fil`);
    urls.add(item.item);
  });
}

function validateOrganization(node, route) {
  assert.equal(node['@id'], registry.organizationId, `${route}: @id Organization`);
  assert.equal(node.name, 'iliprestō', `${route}: nom Organization`);
  assert.equal(node.alternateName, 'ilipresto', `${route}: alternateName Organization`);
  assert.equal(node.url, `${base}/`, `${route}: URL Organization`);
  assert.ok(
    node.description?.toLowerCase().includes('petites annonces'),
    `${route}: positionnement petites annonces absent de la description Organization`,
  );
  assert.ok(
    node.description?.toLowerCase().includes('solution instantanée'),
    `${route}: notion de solution instantanée absente de la description Organization`,
  );
  const logo = node.logo;
  assert.equal(logo?.['@type'], 'ImageObject', `${route}: logo doit être ImageObject`);
  assert.equal(logo?.['@id'], registry.logoId, `${route}: @id logo`);
  assert.equal(logo?.url, `${base}/icons/Icon-512.png`, `${route}: URL logo`);
  assert.equal(logo?.contentUrl, `${base}/icons/Icon-512.png`, `${route}: contentUrl logo`);
  assert.ok(Number(logo?.width) >= 112 && Number(logo?.height) >= 112, `${route}: dimensions logo insuffisantes`);
  assert.equal(node.image?.['@id'], registry.logoId, `${route}: image Organization`);
  assert.equal(node.areaServed?.['@type'], 'Country', `${route}: areaServed type`);
  assert.equal(node.areaServed?.name, 'France', `${route}: portée nationale absente`);
  assert.equal(node.knowsLanguage, 'fr-FR', `${route}: langue Organization`);
  if ('sameAs' in node) {
    assert.ok(Array.isArray(node.sameAs) && node.sameAs.length > 0, `${route}: sameAs vide interdit`);
    node.sameAs.forEach((url) => assertHttpsUrl(url, `${route}: sameAs`));
  }
}

function validateStaticRoute(route, config) {
  const html = read(config.file);
  const canonical = canonicalFor(route);
  assert.ok(html.includes(`<link rel="canonical" href="${canonical}">`), `${route}: canonical incohérente`);

  const documents = parseJsonLd(html, config.file);
  documents.forEach((document) => assert.equal(document['@context'], 'https://schema.org', `${route}: contexte schema.org`));
  const nodes = graphNodes(documents);
  const types = new Set(nodes.flatMap(nodeTypes));

  config.requiredTypes.forEach((type) => assert.ok(types.has(type), `${route}: type ${type} absent`));
  registry.forbiddenTypes.forEach((type) => assert.ok(!types.has(type), `${route}: type ${type} interdit`));

  for (const node of nodes) {
    if (node['@id']) {
      assert.ok(node['@id'].startsWith(base), `${route}: @id hors domaine`);
    }
  }

  const breadcrumb = findType(nodes, 'BreadcrumbList');
  if (breadcrumb) validateBreadcrumb(breadcrumb, route);

  const organization = findType(nodes, 'Organization');
  if (organization) validateOrganization(organization, route);

  const website = findType(nodes, 'WebSite');
  if (website) {
    assert.equal(website['@id'], registry.websiteId, `${route}: @id WebSite`);
    assert.equal(website.url, `${base}/`, `${route}: URL WebSite`);
    assert.equal(website.publisher?.['@id'], registry.organizationId, `${route}: publisher WebSite`);
    assert.equal(website.inLanguage, 'fr-FR', `${route}: langue WebSite`);
  }

  const webpage = findType(nodes, 'WebPage');
  if (webpage) {
    assert.equal(webpage.url, canonical, `${route}: URL WebPage`);
    assert.equal(webpage.isPartOf?.['@id'], registry.websiteId, `${route}: isPartOf WebPage`);
    assert.equal(webpage.inLanguage, 'fr-FR', `${route}: langue WebPage`);
  }

  const service = findType(nodes, 'Service');
  if (service) {
    assert.equal(service.provider?.['@id'], registry.organizationId, `${route}: provider Service`);
    assert.ok(service.areaServed, `${route}: areaServed Service absent`);
  }

  const profile = findType(nodes, 'ProfilePage');
  if (profile) {
    assert.equal(profile.mainEntity?.['@id'], registry.organizationId, `${route}: mainEntity ProfilePage`);
    assert.equal(profile.isPartOf?.['@id'], registry.websiteId, `${route}: isPartOf ProfilePage`);
    assertIsoDate(profile.dateModified, `${route}: dateModified ProfilePage`);
  }

  const article = findType(nodes, 'Article');
  if (article) {
    assert.equal(article.author?.['@id'], registry.organizationId, `${route}: auteur Article`);
    assert.equal(article.publisher?.['@id'], registry.organizationId, `${route}: éditeur Article`);
    assert.equal(article.mainEntityOfPage?.['@id'], `${canonical}#webpage`, `${route}: mainEntityOfPage Article`);
    assert.equal(article.image?.['@id'], registry.logoId, `${route}: image Article`);
    assertIsoDate(article.datePublished, `${route}: datePublished Article`);
    assertIsoDate(article.dateModified, `${route}: dateModified Article`);
    assert.ok(/Publié[\s\S]{0,160}mis à jour le/i.test(html), `${route}: dates Article non visibles`);
  }
}

for (const [route, config] of Object.entries(registry.staticRoutes)) {
  validateStaticRoute(route, config);
}

const legalSource = read('web/public-route-seo.js');
for (const route of registry.dynamicLegalRoutes) {
  assert.ok(legalSource.includes(`'${route}'`), `${route}: route légale absente`);
}
for (const token of [
  "'@type': 'WebPage'",
  "'@type': 'BreadcrumbList'",
  "publisher: {'@id': organizationId}",
  "about: {'@id': organizationId}",
  "isPartOf: {'@id': websiteId}",
]) {
  assert.ok(legalSource.includes(token), `Routes légales: ${token} absent`);
}

const schemaSources = [
  ...Object.values(registry.staticRoutes).map((entry) => read(entry.file)),
  legalSource,
];
for (const forbidden of registry.forbiddenTypes) {
  const pattern = new RegExp(`["']@type["']\\s*:\\s*["']${forbidden}["']`);
  assert.ok(!schemaSources.some((source) => pattern.test(source)), `Type structuré interdit détecté: ${forbidden}`);
}

const readinessWorkflow = read('.github/workflows/structured-data-readiness.yml');
assert.ok(readinessWorkflow.includes('node tools/quality/check_structured_data.mjs'), 'CI JSON-LD absente');
assert.ok(readinessWorkflow.includes('node tools/quality/check_public_page_seo.mjs'), 'CI pages publiques absente');
const productionWorkflow = read('.github/workflows/structured-data-production.yml');
assert.ok(productionWorkflow.includes('Validate and Deploy Firebase'), 'Déclencheur post-déploiement absent');
assert.ok(productionWorkflow.includes('node tools/quality/check_live_structured_data.mjs'), 'Contrôle JSON-LD de production absent');

console.log(`Point 5 SEO: ${Object.keys(registry.staticRoutes).length} pages statiques et ${registry.dynamicLegalRoutes.length} routes légales validées.`);
