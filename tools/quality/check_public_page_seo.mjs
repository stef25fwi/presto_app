import assert from 'node:assert/strict';
import fs from 'node:fs';

const base = 'https://ilipresto.fr';
const staticPages = {
  '/': {file: 'web/index.html'},
  '/guadeloupe': {file: 'web/guadeloupe.html'},
  '/martinique': {file: 'web/martinique.html'},
  '/guyane': {file: 'web/guyane.html'},
  '/a-propos': {file: 'web/a-propos.html'},
  '/guides/comment-fonctionne-ilipresto': {
    file: 'web/guides/comment-fonctionne-ilipresto.html',
  },
};
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
const routes = [...Object.keys(staticPages), ...Object.keys(legal)];
const read = (path) => fs.readFileSync(path, 'utf8');
const extract = (html, regex, label) => {
  const match = html.match(regex);
  assert.ok(match, `${label} absent`);
  return match[1].trim();
};
const canonicalFor = (route) => route === '/' ? `${base}/` : `${base}${route}`;

const titles = new Set();
const descriptions = new Set();
const canonicals = new Set();

for (const [route, page] of Object.entries(staticPages)) {
  const html = read(page.file);
  const title = extract(html, /<title>(.*?)<\/title>/s, `${route}: title`);
  const description = extract(
    html,
    /<meta name="description" content="(.*?)">/s,
    `${route}: meta description`,
  );
  const canonical = extract(
    html,
    /<link rel="canonical" href="(.*?)">/s,
    `${route}: canonical`,
  );
  const h1 = extract(html, /<h1>(.*?)<\/h1>/s, `${route}: H1`);

  assert.ok(title.length >= 20 && title.length <= 70, `${route}: longueur title`);
  assert.ok(description.length >= 120 && description.length <= 180, `${route}: longueur description`);
  assert.ok(h1.length >= 10, `${route}: H1 trop court`);
  assert.equal(canonical, canonicalFor(route));
  assert.ok(html.includes('alt="Logo iliprestō"'), `${route}: alt logo absent`);
  assert.ok((html.match(/<a href=/g) || []).length >= 5, `${route}: maillage interne insuffisant`);
  if (route !== '/') {
    assert.ok(html.includes('aria-label="Fil d’Ariane"'), `${route}: fil d’Ariane absent`);
    assert.ok(/"@type"\s*:\s*"BreadcrumbList"/.test(html), `${route}: BreadcrumbList absent`);
  }
  assert.ok(!titles.has(title), `${route}: title dupliqué`);
  assert.ok(!descriptions.has(description), `${route}: description dupliquée`);
  assert.ok(!canonicals.has(canonical), `${route}: canonical dupliquée`);
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
  const url = canonicalFor(route);
  assert.ok(sitemap.includes(`<loc>${url}</loc>`), `Sitemap: ${url} absent`);
  assert.equal(sitemap.split(`<loc>${url}</loc>`).length - 1, 1, `Sitemap: ${url} dupliqué`);
}

const firebase = JSON.parse(read('firebase.json'));
const hostedPages = {
  '/guadeloupe': '/guadeloupe.html',
  '/martinique': '/martinique.html',
  '/guyane': '/guyane.html',
  '/a-propos': '/a-propos.html',
  '/guides/comment-fonctionne-ilipresto': '/guides/comment-fonctionne-ilipresto.html',
};
for (const hosting of firebase.hosting) {
  for (const [route, destination] of Object.entries(hostedPages)) {
    assert.ok(
      hosting.rewrites.some((rule) => rule.source === route && rule.destination === destination),
      `${hosting.target}: rewrite ${route} absente`,
    );
    for (const source of [`${route}/`, destination]) {
      assert.ok(
        hosting.redirects.some(
          (rule) => rule.source === source && rule.destination === route && rule.type === 301,
        ),
        `${hosting.target}: redirection ${source} absente`,
      );
    }
  }
}

const productionWorkflow = read('.github/workflows/structured-data-production.yml');
assert.ok(
  productionWorkflow.includes('node tools/quality/check_live_structured_data.mjs'),
  'Smoke test des dix pages publiques absent',
);

console.log('Point 4 SEO: 10 pages publiques validées.');
