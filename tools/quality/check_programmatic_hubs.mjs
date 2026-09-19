import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const registry = JSON.parse(fs.readFileSync('web/programmatic-seo-registry.json', 'utf8'));
const sitemap = fs.readFileSync('web/sitemap-local.xml', 'utf8');

function hubRoute(intent, service = null) {
  return service
    ? `${intent.routePrefix}/${service.slug}/`
    : `${intent.routePrefix}/`;
}

function readHub(route) {
  const file = path.join('web', route.replace(/^\//, ''), 'index.html');
  assert.ok(fs.existsSync(file), `${route}: hub absent`);
  return fs.readFileSync(file, 'utf8');
}

const canonicals = new Set();
const titles = new Set();
let visited = 0;
let indexable = 0;

for (const intent of registry.intents) {
  const route = hubRoute(intent);
  const html = readHub(route);
  const canonical = `${registry.baseUrl}${route}`;
  const title = html.match(/<title>(.*?)<\/title>/s)?.[1]?.trim();
  const robots = html.match(/<meta name="robots" content="(.*?)">/s)?.[1]?.trim();

  visited += 1;
  assert.ok(title && title.length >= 25 && title.length <= 70, `${route}: title invalide`);
  assert.ok(html.includes(`<link rel="canonical" href="${canonical}">`), `${route}: canonical absente`);
  assert.ok(html.includes('"@type":"CollectionPage"'), `${route}: CollectionPage JSON-LD absent`);
  assert.ok(html.includes('"@type":"ItemList"'), `${route}: ItemList JSON-LD absent`);
  assert.ok(html.includes('"@type":"BreadcrumbList"'), `${route}: BreadcrumbList absent`);
  assert.ok(!/"@type"\s*:\s*"JobPosting"/.test(html), `${route}: JobPosting interdit`);
  assert.ok(!canonicals.has(canonical), `${route}: canonical dupliquée`);
  assert.ok(!titles.has(title), `${route}: title dupliqué`);
  canonicals.add(canonical);
  titles.add(title);

  for (const service of registry.services) {
    assert.ok(
      html.includes(`href="${hubRoute(intent, service)}"`),
      `${route}: lien vers le hub ${service.slug} absent`,
    );
  }

  const inSitemap = sitemap.includes(`<loc>${canonical}</loc>`);
  if (robots?.startsWith('index,follow')) {
    indexable += 1;
    assert.ok(inSitemap, `${route}: hub indexable absent du sitemap`);
  } else {
    assert.equal(robots, 'noindex,follow', `${route}: robots inattendu`);
    assert.ok(!inSitemap, `${route}: hub noindex présent dans le sitemap`);
  }

  for (const service of registry.services) {
    const serviceRoute = hubRoute(intent, service);
    const serviceHtml = readHub(serviceRoute);
    const serviceCanonical = `${registry.baseUrl}${serviceRoute}`;
    const serviceTitle = serviceHtml.match(/<title>(.*?)<\/title>/s)?.[1]?.trim();
    const serviceRobots = serviceHtml.match(/<meta name="robots" content="(.*?)">/s)?.[1]?.trim();

    visited += 1;
    assert.ok(serviceTitle && serviceTitle.length >= 25 && serviceTitle.length <= 70, `${serviceRoute}: title invalide`);
    assert.ok(serviceHtml.includes(`<link rel="canonical" href="${serviceCanonical}">`), `${serviceRoute}: canonical absente`);
    assert.ok(serviceHtml.includes(`href="${route}"`), `${serviceRoute}: retour au hub parent absent`);
    assert.ok(serviceHtml.includes('"@type":"CollectionPage"'), `${serviceRoute}: CollectionPage JSON-LD absent`);
    assert.ok(serviceHtml.includes('"@type":"ItemList"'), `${serviceRoute}: ItemList JSON-LD absent`);
    assert.ok(serviceHtml.includes('"@type":"BreadcrumbList"'), `${serviceRoute}: BreadcrumbList absent`);
    assert.ok(!/"@type"\s*:\s*"JobPosting"/.test(serviceHtml), `${serviceRoute}: JobPosting interdit`);
    assert.ok(!canonicals.has(serviceCanonical), `${serviceRoute}: canonical dupliquée`);
    assert.ok(!titles.has(serviceTitle), `${serviceRoute}: title dupliqué`);
    canonicals.add(serviceCanonical);
    titles.add(serviceTitle);

    const serviceInSitemap = sitemap.includes(`<loc>${serviceCanonical}</loc>`);
    if (serviceRobots?.startsWith('index,follow')) {
      indexable += 1;
      assert.ok(serviceInSitemap, `${serviceRoute}: hub indexable absent du sitemap`);
      assert.match(serviceHtml, /href="\/(services|missions)\/[^/]+\/[^/]+\//, `${serviceRoute}: aucune page locale active liée`);
    } else {
      assert.equal(serviceRobots, 'noindex,follow', `${serviceRoute}: robots inattendu`);
      assert.ok(!serviceInSitemap, `${serviceRoute}: hub noindex présent dans le sitemap`);
    }
  }
}

const expected = registry.intents.length * (registry.services.length + 1);
assert.equal(visited, expected, 'Nombre de hubs générés incohérent');
assert.equal(canonicals.size, expected, 'Canonicals hubs non uniques');
assert.equal(titles.size, expected, 'Titles hubs non uniques');

console.log(`SEO hubs: ${visited} hubs validés, ${indexable} indexables.`);
