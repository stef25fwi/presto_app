import fs from 'node:fs';
import path from 'node:path';

const registryPath = 'web/programmatic-seo-registry.json';
const signalsPath = 'quality/seo-programmatic-local-signals.json';
const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
const signals = JSON.parse(fs.readFileSync(signalsPath, 'utf8'));
const SAFE_PUBLIC_ID = /^[A-Za-z0-9_-]{6,128}$/;

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

function signalsAreFresh() {
  const generatedMs = Date.parse(String(signals.generatedAt || ''));
  if (!Number.isFinite(generatedMs)) return false;
  const maxAgeHours = Number(registry.activationGate.maxSignalAgeHours || 24);
  const ageMs = Date.now() - generatedMs;
  return ageMs >= -5 * 60 * 1000 && ageMs <= maxAgeHours * 60 * 60 * 1000;
}

function readSignals(key) {
  const value = signals.pages?.[key] || {};
  const listingPreviews = Array.isArray(value.listingPreviews)
    ? value.listingPreviews
      .filter((item) => SAFE_PUBLIC_ID.test(String(item?.id || '')) && String(item?.title || '').trim().length >= 12)
      .slice(0, 5)
      .map((item) => ({
        id: String(item.id),
        title: String(item.title).trim().slice(0, 140),
        publishedAt: item.publishedAt ? String(item.publishedAt) : null,
      }))
    : [];
  return {
    activeListings: Number(value.activeListings || 0),
    qualifiedProfiles: Number(value.qualifiedProfiles || 0),
    recentListings: Number(value.recentListings || 0),
    recentProfiles: Number(value.recentProfiles || 0),
    listingPreviews,
  };
}

function activationFor(intent, key, city) {
  const value = readSignals(key);
  const gate = registry.activationGate;
  const localIntroReady = !gate.requireUniqueLocalIntro || String(city.localIntro || '').trim().length >= 60;
  const fresh = signalsAreFresh();
  let eligible = false;

  if (intent.key === 'services') {
    const serviceGate = gate.intentGates?.services || {};
    const minQualifiedProfiles = Number(serviceGate.minQualifiedProfiles || gate.minRealEntities || 3);
    const minRecentProfiles = Number(serviceGate.minRecentProfiles || gate.minRecentEntities || 1);
    eligible = fresh
      && localIntroReady
      && value.qualifiedProfiles >= minQualifiedProfiles
      && value.recentProfiles >= minRecentProfiles;
  } else if (intent.key === 'missions') {
    const missionGate = gate.intentGates?.missions || {};
    const minActiveListings = Number(missionGate.minActiveListings || gate.minRealEntities || 3);
    const minRecentListings = Number(missionGate.minRecentListings || gate.minRecentEntities || 1);
    eligible = fresh
      && localIntroReady
      && value.activeListings >= minActiveListings
      && value.recentListings >= minRecentListings
      && value.listingPreviews.length >= minActiveListings;
  }

  return {
    ...value,
    realEntities: intent.key === 'services' ? value.qualifiedProfiles : value.activeListings,
    recentEntities: intent.key === 'services' ? value.recentProfiles : value.recentListings,
    signalsFresh: fresh,
    eligible,
  };
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

function statusCopy(intent, activation) {
  if (!activation.signalsFresh) {
    return 'Cette page locale reste volontairement hors index Google tant qu’un agrégat de production récent et vérifiable n’est pas disponible.';
  }
  if (!activation.eligible && intent.key === 'services') {
    return 'Cette page reste hors index tant que suffisamment de profils publics, qualifiés, récents et publiés avec un consentement explicite ne sont pas disponibles localement.';
  }
  if (!activation.eligible) {
    return 'Cette page reste hors index tant que suffisamment d’annonces publiques, complètes et récentes ne sont pas disponibles localement.';
  }
  if (intent.key === 'services') {
    return 'Cette page est indexable car elle dispose d’un seuil suffisant de profils publics, qualifiés et récents dans cette zone.';
  }
  return 'Cette page est indexable car elle présente un seuil suffisant d’annonces publiques, complètes et récentes dans cette zone.';
}

function renderListingPreviews(intent, activation) {
  if (intent.key !== 'missions' || !activation.eligible) return '';
  const items = activation.listingPreviews
    .map((listing) => `<li><a href="/annonces/${encodeURIComponent(listing.id)}/">${escapeHtml(listing.title)}</a></li>`)
    .join('');
  return `<section aria-label="Annonces locales"><h2>Annonces locales disponibles</h2><p>Exemples d’annonces publiques correspondant à cette catégorie et à cette ville :</p><ul>${items}</ul></section>`;
}

function renderPage(intent, service, city) {
  const key = pageKey(intent, service, city);
  const activation = activationFor(intent, key, city);
  const route = routeFor(intent, service, city);
  const canonical = `${registry.baseUrl}${route}`;
  const title = titleFor(intent, service, city);
  const h1 = h1For(intent, service, city);
  const description = descriptionFor(intent, service, city);
  const robots = activation.eligible ? registry.activationGate.activeRobots : registry.activationGate.inactiveRobots;
  const oppositeIntent = registry.intents.find((candidate) => candidate.key !== intent.key);
  const oppositeRoute = routeFor(oppositeIntent, service, city);
  const oppositeActivation = activationFor(oppositeIntent, pageKey(oppositeIntent, service, city), city);
  const territory = territoryRoute(city);
  const keywords = service.keywords.map((keyword) => `<li>${escapeHtml(keyword)}</li>`).join('');
  const audienceCopy = intent.key === 'services'
    ? 'Cette page répond aux recherches de personnes qui cherchent une compétence ou une aide locale pour réaliser un service du quotidien.'
    : 'Cette page répond aux recherches de personnes qui souhaitent repérer des besoins locaux correspondant à leurs compétences. Une mission de service n’est pas automatiquement une offre d’emploi salarié.';
  const listingSection = renderListingPreviews(intent, activation);
  const oppositeLink = oppositeActivation.eligible
    ? `<a href="${escapeHtml(oppositeRoute)}">${oppositeIntent.key === 'services' ? 'Chercher ce service' : 'Voir les missions correspondantes'}</a>`
    : '';

  const graph = [
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
  ];

  if (intent.key === 'missions' && activation.eligible) {
    graph.push({
      '@type': 'ItemList',
      '@id': `${canonical}#annonces`,
      name: `Annonces ${service.serviceTitle} à ${city.name}`,
      itemListElement: activation.listingPreviews.map((listing, index) => ({
        '@type': 'ListItem',
        position: index + 1,
        name: listing.title,
        url: `${registry.baseUrl}/annonces/${listing.id}/`,
      })),
    });
  }

  const jsonLd = {'@context': 'https://schema.org', '@graph': graph};

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
        <article><h2>Données réelles avant indexation</h2><p>L’indexation n’est activée qu’après atteinte du seuil minimal de signaux réels, récents et adaptés à l’intention de recherche.</p></article>
        <article><h2>Échange direct</h2><p>iliprestō facilite la mise en relation. La plateforme n’est ni employeur, ni agence d’intérim, et ne garantit ni mission, ni revenu, ni délai de réponse.</p></article>
      </section>
      ${listingSection}
      <h2>Recherches associées</h2>
      <ul>${keywords}</ul>
      <p class="public-status">${escapeHtml(statusCopy(intent, activation))}</p>
      <nav class="public-links" aria-label="Explorer iliprestō">
        ${oppositeLink}
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
      const activation = activationFor(intent, pageKey(intent, service, city), city);
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
