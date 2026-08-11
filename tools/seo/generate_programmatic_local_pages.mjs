import fs from 'node:fs';
import path from 'node:path';

const registryPath = 'web/programmatic-seo-registry.json';
const signalsPath = 'quality/seo-programmatic-local-signals.json';
const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
const signals = JSON.parse(fs.readFileSync(signalsPath, 'utf8'));

const escapeHtml = (value) => String(value)
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&#39;');

const escapeJson = (value) => JSON.stringify(value).replaceAll('<', '\\u003c');

function pageKey(intent, service, city) {
  return `${intent.key}:${service.key}:${city.slug}`;
}

function readSignals(key) {
  const value = signals.pages?.[key] || {};
  return {
    activeListings: Number(value.activeListings || 0),
    qualifiedProfiles: Number(value.qualifiedProfiles || 0),
    recentListings: Number(value.recentListings || 0),
    recentProfiles: Number(value.recentProfiles || 0),
  };
}

function activationFor(key, city) {
  const value = readSignals(key);
  const realEntities = value.activeListings + value.qualifiedProfiles;
  const recentEntities = value.recentListings + value.recentProfiles;
  const gate = registry.activationGate;
  const eligible = realEntities >= gate.minRealEntities
    && recentEntities >= gate.minRecentEntities
    && (!gate.requireUniqueLocalIntro || String(city.localIntro || '').trim().length >= 60);
  return {...value, realEntities, recentEntities, eligible};
}

function routeFor(intent, service, city) {
  return `${intent.routePrefix}/${service.slug}/${city.slug}/`;
}

function territoryRoute(city) {
  const territory = city.territory.toLowerCase();
  if (territory === 'guadeloupe') return '/guadeloupe';
  if (territory === 'martinique') return '/martinique';
  if (territory === 'guyane') return '/guyane';
  return '/';
}

function shortMissionLabel(service) {
  if (service.key === 'bricolage') return 'bricolage';
  if (service.key === 'jardinage') return 'jardinage';
  if (service.key === 'aide-demenagement') return 'déménagement';
  return service.serviceTitle.toLowerCase();
}

function titleFor(intent, service, city) {
  const title = intent.key === 'services'
    ? `${service.serviceTitle} à ${city.name} | iliprestō`
    : `Missions ${shortMissionLabel(service)} à ${city.name} | iliprestō`;
  if (title.length <= 70) return title;
  return `${service.serviceTitle} ${city.name} | iliprestō`.slice(0, 70);
}

function h1For(intent, service, city) {
  return intent.key === 'services'
    ? `Trouvez ${service.serviceLower} à ${city.name}`
    : `Trouvez des missions ${shortMissionLabel(service)} à ${city.name}`;
}

function descriptionFor(intent, service, city) {
  if (intent.key === 'services') {
    return `Recherchez ${service.serviceLower} à ${city.name} (${city.postalCode}) et consultez les besoins, annonces et profils locaux disponibles sur iliprestō.`;
  }
  return `Trouvez des missions ${shortMissionLabel(service)} à ${city.name} (${city.postalCode}) et consultez les besoins de services publiés localement sur iliprestō.`;
}

function statusCopy(activation) {
  if (!activation.eligible) {
    return 'Cette page locale reste volontairement hors index Google tant que suffisamment d’annonces ou de profils réels et récents ne sont pas disponibles dans cette zone.';
  }
  return 'Cette page est ouverte à l’indexation car elle dispose d’un niveau minimal de données locales réelles et récentes selon le garde-fou SEO iliprestō.';
}

function renderPage(intent, service, city) {
  const key = pageKey(intent, service, city);
  const activation = activationFor(key, city);
  const route = routeFor(intent, service, city);
  const canonical = `${registry.baseUrl}${route}`;
  const title = titleFor(intent, service, city);
  const h1 = h1For(intent, service, city);
  const description = descriptionFor(intent, service, city);
  const robots = activation.eligible ? registry.activationGate.activeRobots : registry.activationGate.inactiveRobots;
  const oppositeIntent = registry.intents.find((candidate) => candidate.key !== intent.key);
  const oppositeRoute = routeFor(oppositeIntent, service, city);
  const territory = territoryRoute(city);
  const keywords = service.keywords.map((keyword) => `<li>${escapeHtml(keyword)}</li>`).join('');
  const audienceCopy = intent.key === 'services'
    ? 'Cette page répond aux recherches de personnes qui cherchent une compétence ou une aide locale pour réaliser un service du quotidien.'
    : 'Cette page répond aux recherches de personnes qui souhaitent repérer des besoins locaux correspondant à leurs compétences. Une mission de service n’est pas automatiquement une offre d’emploi salarié.';

  const jsonLd = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'WebPage',
        '@id': `${canonical}#webpage`,
        url: canonical,
        name: title,
        description,
        inLanguage: 'fr-FR',
        isPartOf: {'@id': `${registry.baseUrl}/#website`},
        publisher: {'@id': `${registry.baseUrl}/#organization`},
        mainEntity: {'@id': `${canonical}#service`},
        breadcrumb: {'@id': `${canonical}#breadcrumb`},
      },
      {
        '@type': 'Service',
        '@id': `${canonical}#service`,
        name: `${service.serviceTitle} – ${city.name}`,
        serviceType: service.taxonomyValue,
        description,
        provider: {'@id': `${registry.baseUrl}/#organization`},
        areaServed: {
          '@type': 'City',
          name: city.name,
          containedInPlace: {'@type': 'AdministrativeArea', name: city.territory},
        },
        availableChannel: {'@type': 'ServiceChannel', serviceUrl: canonical},
      },
      {
        '@type': 'BreadcrumbList',
        '@id': `${canonical}#breadcrumb`,
        itemListElement: [
          {'@type': 'ListItem', position: 1, name: 'Accueil', item: `${registry.baseUrl}/`},
          {'@type': 'ListItem', position: 2, name: intent.key === 'services' ? 'Services' : 'Missions', item: `${registry.baseUrl}${intent.routePrefix}/`},
          {'@type': 'ListItem', position: 3, name: service.serviceTitle, item: `${registry.baseUrl}${intent.routePrefix}/${service.slug}/`},
          {'@type': 'ListItem', position: 4, name: city.name, item: canonical},
        ],
      },
    ],
  };

  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="robots" content="${escapeHtml(robots)}">
  <meta name="theme-color" content="#FF6600">
  <link rel="canonical" href="${escapeHtml(canonical)}">
  <link rel="alternate" hreflang="fr-FR" href="${escapeHtml(canonical)}">
  <link rel="icon" type="image/png" sizes="192x192" href="/icons/Icon-192.png?v=20260811">
  <link rel="apple-touch-icon" href="/icons/Icon-192.png?v=20260811">
  <link rel="stylesheet" href="/public-pages.css">
  <meta property="og:type" content="website">
  <meta property="og:locale" content="fr_FR">
  <meta property="og:site_name" content="iliprestō">
  <meta property="og:url" content="${escapeHtml(canonical)}">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="https://ilipresto.fr/icons/Icon-512.png">
  <meta property="og:image:alt" content="Logo iliprestō">
  <title>${escapeHtml(title)}</title>
  <script type="application/ld+json">${escapeJson(jsonLd)}</script>
</head>
<body class="public-page">
  <div class="public-shell">
    <header><a class="public-brand" href="/" aria-label="Accueil iliprestō"><img src="/assets/assets/images/ilipresto_splash_logo.webp" alt="Logo iliprestō" width="54" height="54"><span>iliprestō</span></a></header>
    <nav class="public-breadcrumb" aria-label="Fil d’Ariane"><ol><li><a href="/">Accueil</a></li><li>${intent.key === 'services' ? 'Services' : 'Missions'}</li><li>${escapeHtml(service.serviceTitle)}</li><li aria-current="page">${escapeHtml(city.name)}</li></ol></nav>
    <main class="public-card">
      <span class="public-kicker">${escapeHtml(city.territory)} · ${escapeHtml(city.postalCode)}</span>
      <h1>${escapeHtml(h1)}</h1>
      <p class="public-lead">${escapeHtml(city.localIntro)} ${escapeHtml(audienceCopy)}</p>
      <section class="public-grid" aria-label="Informations locales">
        <article><h2>Recherche locale précise</h2><p>La page associe une catégorie de service, une ville et une intention de recherche afin d’éviter les pages génériques ou dupliquées.</p></article>
        <article><h2>Données réelles avant indexation</h2><p>L’indexation n’est activée qu’après atteinte du seuil minimal de signaux réels et récents défini par le SEO Activation Gate.</p></article>
        <article><h2>Échange direct</h2><p>iliprestō facilite la mise en relation. La plateforme n’est ni employeur, ni agence d’intérim, et ne garantit ni mission, ni revenu, ni délai de réponse.</p></article>
      </section>
      <h2>Recherches associées</h2>
      <ul>${keywords}</ul>
      <p class="public-status">${escapeHtml(statusCopy(activation))}</p>
      <nav class="public-links" aria-label="Explorer iliprestō">
        <a href="${escapeHtml(oppositeRoute)}">${oppositeIntent.key === 'services' ? 'Chercher ce service' : 'Voir les missions correspondantes'}</a>
        <a href="${escapeHtml(territory)}">Services en ${escapeHtml(city.territory)}</a>
        <a href="/trouver-une-personne-disponible/">Trouver une personne disponible</a>
        <a href="/guides/comment-fonctionne-ilipresto">Comment fonctionne iliprestō ?</a>
        <a href="/guides/creer-micro-entreprise-services/">Créer une activité de services</a>
      </nav>
    </main>
    <footer class="public-footer"><span>ilipresto.fr — ${escapeHtml(service.serviceTitle)} à ${escapeHtml(city.name)}</span><a href="/mentions-legales">Mentions légales</a><a href="/confidentialite">Confidentialité</a><a href="/cgu">Conditions d’utilisation</a></footer>
  </div>
</body>
</html>`;
}

const generated = [];
for (const intent of registry.intents) {
  for (const service of registry.services) {
    for (const city of registry.cities) {
      const route = routeFor(intent, service, city);
      const output = path.join('web', route, 'index.html');
      fs.mkdirSync(path.dirname(output), {recursive: true});
      fs.writeFileSync(output, renderPage(intent, service, city));
      const activation = activationFor(pageKey(intent, service, city), city);
      generated.push({route, eligible: activation.eligible});
    }
  }
}

const activeUrls = generated
  .filter((page) => page.eligible)
  .map((page) => `  <url>\n    <loc>${registry.baseUrl}${page.route}</loc>\n    <changefreq>daily</changefreq>\n  </url>`)
  .join('\n');

fs.writeFileSync(
  'web/sitemap-local.xml',
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${activeUrls}${activeUrls ? '\n' : ''}</urlset>\n`,
);

console.log(`SEO local: ${generated.length} pages générées, ${generated.filter((page) => page.eligible).length} indexables.`);
