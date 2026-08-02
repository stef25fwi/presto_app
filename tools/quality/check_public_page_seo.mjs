import assert from 'node:assert/strict';
import fs from 'node:fs';

const base = 'https://ilipresto.fr';
const regions = ['guadeloupe', 'martinique', 'guyane'];
const legal = {
  '/mentions-legales': {
    title: 'Mentions légales | iliprestō',
    h1: 'Mentions légales d’iliprestō',
  },
  '/confidentialite': {
    title: 'Politique de confidentialité | iliprestō',
    h1: 'Politique de confidentialité d’iliprestō',
  },
  '/cgu': {
    title: 'Conditions générales d’utilisation | iliprestō',
    h1: 'Conditions générales d’utilisation',
  },
  '/suppression-compte': {
    title: 'Supprimer votre compte iliprestō',
    h1: 'Supprimer votre compte iliprestō',
  },
};
const routes = ['/', ...regions.map((slug) => `/${slug}`), ...Object.keys(legal)];
const read = (path) => fs.readFileSync(path, 'utf8');
const extract = (html, regex, label) => {
  const match = html.match(regex);
  assert.ok(match, `${label} absent`);
  return match[1].trim();
};

const titles = new Set();
const descriptions = new Set();
const canonicals = new Set();

for (const slug of regions) {
  const html = read(`web/${slug}.html`);
  const title = extract(html, /<title>(.*?)<\/title>/s, `${slug}: title`);
  const description = extract(
    html,
    /<meta name="description" content="(.*?)">/s,
    `${slug}: meta description`,
  );
  const canonical = extract(
    html,
    /<link rel="canonical" href="(.*?)">/s,
    `${slug}: canonical`,
  );
  const h1 = extract(html, /<h1>(.*?)<\/h1>/s, `${slug}: H1`);

  assert.ok(title.length >= 20 && title.length <= 70, `${slug}: longueur title`);
  assert.ok(description.length >= 120 && description.length <= 180, `${slug}: longueur description`);
  assert.ok(h1.length >= 20, `${slug}: H1 trop court`);
  assert.equal(canonical, `${base}/${slug}`);
  assert.ok(html.includes('aria-label="Fil d’Ariane"'), `${slug}: fil d’Ariane absent`);
  assert.ok(html.includes('alt="Logo iliprestō"'), `${slug}: alt logo absent`);
  assert.ok(html.includes('"@type":"BreadcrumbList"'), `${slug}: BreadcrumbList absent`);
  assert.ok(html.includes('"@type":"Service"'), `${slug}: Service JSON-LD absent`);
  assert.ok((html.match(/<a href=/g) || []).length >= 7, `${slug}: maillage interne insuffisant`);
  assert.ok(!titles.has(title), `${slug}: title dupliqué`);
  assert.ok(!descriptions.has(description), `${slug}: description dupliquée`);
  assert.ok(!canonicals.has(canonical), `${slug}: canonical dupliquée`);
  titles.add(title);
  descriptions.add(description);
  canonicals.add(canonical);
}

const legalSeo = read('web/public-route-seo.js');
for (const [route, page] of Object.entries(legal)) {
  assert.ok(legalSeo.includes(`'${route}'`), `${route}: registre SEO absent`);
  assert.ok(legalSeo.includes(`title: '${page.title}'`), `${route}: title absent`);
  assert.ok(legalSeo.includes(`h1: '${page.h1}'`), `${route}: H1 absent`);
  assert.ok(legalSeo.includes("'@type': 'BreadcrumbList'"), 'JSON-LD légal absent');
  assert.ok(!titles.has(page.title), `${route}: title dupliqué`);
  titles.add(page.title);
}

const index = read('web/index.html');
assert.ok(index.includes('href="/public-pages.css"'), 'Accueil: feuille publique absente');
assert.ok(index.includes('src="/public-route-seo.js"'), 'Accueil: script SEO légal absent');
for (const route of routes.slice(1)) {
  assert.ok(index.includes(`href="${route}"`), `Accueil: lien ${route} absent`);
}

const sitemap = read('web/sitemap.xml');
for (const route of routes) {
  const url = route === '/' ? `${base}/` : `${base}${route}`;
  assert.ok(sitemap.includes(`<loc>${url}</loc>`), `Sitemap: ${url} absent`);
  assert.equal(sitemap.split(`<loc>${url}</loc>`).length - 1, 1, `Sitemap: ${url} dupliqué`);
}

const firebase = JSON.parse(read('firebase.json'));
for (const hosting of firebase.hosting) {
  for (const slug of regions) {
    assert.ok(
      hosting.rewrites.some((rule) => rule.source === `/${slug}` && rule.destination === `/${slug}.html`),
      `${hosting.target}: rewrite /${slug} absente`,
    );
    for (const source of [`/${slug}/`, `/${slug}.html`]) {
      assert.ok(
        hosting.redirects.some(
          (rule) => rule.source === source && rule.destination === `/${slug}` && rule.type === 301,
        ),
        `${hosting.target}: redirection ${source} absente`,
      );
    }
  }
}

const deploy = read('.github/workflows/deploy.yml');
for (const route of routes) {
  const url = route === '/' ? `${base}/` : `${base}${route}`;
  assert.ok(deploy.includes(url), `Smoke test absent: ${url}`);
}

console.log('Point 4 SEO: 8 pages publiques validées.');
