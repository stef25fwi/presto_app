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

function publicSlug(value, fallback) {
  const slug = String(value || '')
    .trim()
    .toLowerCase()
    .replaceAll('œ', 'oe')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[’']/g, '-')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 72)
    .replace(/-$/g, '');
  return slug.length >= 3 ? slug : fallback;
}

function postalCodesForCity(city) {
  const candidates = [
    city.postalCode,
    ...(Array.isArray(city.postalCodes) ? city.postalCodes : []),
  ];
  return [...new Set(candidates
    .map((value) => String(value || '').trim())
    .filter((value) => /^\d{5}$/.test(value)))];
}

function postalLabelForCity(city) {
  const codes = postalCodesForCity(city);
  if (codes.length === 0) return '';
  if (codes.length === 1) return codes[0];
  return `${codes[0]} + ${codes.length - 1} autres codes`;
}

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
  const profilePreviews = Array.isArray(value.profilePreviews)
    ? value.profilePreviews
      .filter((item) => /^[a-f0-9]{24}$/.test(String(item?.publicId || ''))
        && String(item?.companyName || '').trim().length >= 2
        && String(item?.activity || '').trim().length >= 3)
      .slice(0, 5)
      .map((item) => ({
        publicId: String(item.publicId),
        companyName: String(item.companyName).trim().slice(0, 140),
        activity: String(item.activity).trim().slice(0, 140),
        publishedAt: item.publishedAt ? String(item.publishedAt) : null,
        updatedAt: item.updatedAt ? String(item.updatedAt) : null,
      }))
    : [];
  return {
    activeListings: Number(value.activeListings || 0),
    qualifiedProfiles: Number(value.qualifiedProfiles || 0),
    recentListings: Number(value.recentListings || 0),
    recentProfiles: Number(value.recentProfiles || 0),
    listingPreviews,
    profilePreviews,
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
      && value.recentProfiles >= minRecentProfiles
      && value.profilePreviews.length >= minQualifiedProfiles;
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
  const postalLabel = postalLabelForCity(city);
  const postalSuffix = postalLabel ? ` (${postalLabel})` : '';
  if (intent.key === 'services') {
    return `Recherchez ${service.serviceLower} à ${city.name}${postalSuffix} et consultez les besoins, annonces et profils locaux disponibles sur iliprestō.`;
  }
  return `Trouvez des missions ${shortMissionLabel(service)} à ${city.name}${postalSuffix} et consultez les besoins de services publiés localement sur iliprestō.`;
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
    .map((listing) => `<li><a href="/annonces/${publicSlug(listing.title, 'annonce')}/${encodeURIComponent(listing.id)}/">${escapeHtml(listing.title)}</a></li>`)
    .join('');
  return `<section aria-label="Annonces locales"><h2>Annonces locales disponibles</h2><p>Exemples d’annonces publiques correspondant à cette catégorie et à cette ville :</p><ul>${items}</ul></section>`;
}

function renderProfilePreviews(intent, activation) {
  if (intent.key !== 'services' || !activation.eligible) return '';
  const items = activation.profilePreviews
    .map((profile) => `<li><a href="/prestataires/${publicSlug(profile.companyName, 'prestataire')}/${encodeURIComponent(profile.publicId)}/"><strong>${escapeHtml(profile.companyName)}</strong></a> — ${escapeHtml(profile.activity)}</li>`)
    .join('');
  return `<section aria-label="Prestataires locaux"><h2>Prestataires disponibles à proximité</h2><p>Profils professionnels vérifiés ayant choisi de rendre leur profil public :</p><ul>${items}</ul></section>`;
}


function formatSignalDate() {
  const parsed = new Date(String(signals.generatedAt || ''));
  if (Number.isNaN(parsed.getTime())) return '';
  return new Intl.DateTimeFormat('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(parsed);
}

function pluralizeCount(count, singular, plural = `${singular}s`) {
  return `${count} ${count > 1 ? plural : singular}`;
}

function renderLocalStats(intent, service, city, activation) {
  if (!activation.eligible || !activation.signalsFresh) return '';
  const sourceDate = formatSignalDate();
  const windowDays = Number(registry.activationGate.recentWindowDays || 90);

  if (intent.key === 'services') {
    const total = activation.qualifiedProfiles;
    const recent = activation.recentProfiles;
    const uniqueCopy = `À ${city.name}, la page ${service.serviceTitle} s’appuie sur ${pluralizeCount(total, 'profil public qualifié')} correspondant à cette catégorie. ${pluralizeCount(recent, 'profil', 'profils')} ont été publiés ou mis à jour au cours des ${windowDays} derniers jours.`;
    return `<section aria-label="Statistiques locales réelles"><h2>Disponibilité locale mesurée</h2><p>${escapeHtml(uniqueCopy)}</p><p class="public-status">Données publiques agrégées${sourceDate ? ` le ${escapeHtml(sourceDate)}` : ''}. Aucun volume n’est estimé ou extrapolé.</p></section>`;
  }

  const total = activation.activeListings;
  const recent = activation.recentListings;
  const uniqueCopy = `À ${city.name}, la catégorie ${service.serviceTitle} compte ${pluralizeCount(total, 'annonce publique active')}. ${pluralizeCount(recent, 'annonce', 'annonces')} ont été publiées au cours des ${windowDays} derniers jours.`;
  return `<section aria-label="Statistiques locales réelles"><h2>Activité locale mesurée</h2><p>${escapeHtml(uniqueCopy)}</p><p class="public-status">Données publiques agrégées${sourceDate ? ` le ${escapeHtml(sourceDate)}` : ''}. Aucun volume n’est estimé ou extrapolé.</p></section>`;
}

function localMarketCopy(intent, service, city, activation) {
  if (!activation.eligible) return '';
  const primaryKeyword = String(service.keywords?.[0] || service.serviceTitle);
  if (intent.key === 'services') {
    return `Pour une recherche « ${primaryKeyword} » à ${city.name}, iliprestō relie cette page aux profils publics qui ont choisi d’être visibles sur le web et dont la catégorie correspond à ${service.serviceTitle}. Le contenu local dépend donc des profils réellement publiés dans ${city.territory}, et non d’un texte générique dupliqué entre villes.`;
  }
  return `Pour une recherche de mission ${shortMissionLabel(service)} à ${city.name}, iliprestō relie cette page aux annonces publiques réellement classées dans ${service.serviceTitle}. Le contenu local évolue avec les besoins publiés dans ${city.territory}, sans transformer ces missions en offres d’emploi salarié.`;
}

function renderPage(intent, service, city) {
  const key = pageKey(intent, service, city);
  const activation = activationFor(intent, key, city);
  const route = routeFor(intent, service, city);
  const canonical = `${registry.baseUrl}${route}`;
  const title = titleFor(intent, service, city);
  const h1 = h1For(intent, service, city);
  const description = descriptionFor(intent, service, city);
  const postalLabel = postalLabelForCity(city);
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
  const profileSection = renderProfilePreviews(intent, activation);
  const localStatsSection = renderLocalStats(intent, service, city, activation);
  const localMarket = localMarketCopy(intent, service, city, activation);
  const oppositeLink = oppositeActivation.eligible
    ? `<a href="${escapeHtml(oppositeRoute)}">${oppositeIntent.key === 'services' ? 'Chercher ce service' : 'Voir les missions correspondantes'}</a>`
    : '';

  const graph = [
    {
      '@type': 'CollectionPage',
      '@id': `${canonical}#webpage`,
      url: canonical,
      name: title,
      description,
      inLanguage: 'fr-FR',
      isPartOf: {'@id': `${registry.baseUrl}/#website`},
      publisher: {'@id': `${registry.baseUrl}/#organization`},
      mainEntity: activation.eligible
        ? {'@id': `${canonical}#${intent.key === 'services' ? 'prestataires' : 'annonces'}`}
        : {'@id': `${canonical}#service`},
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
        url: `${registry.baseUrl}/annonces/${publicSlug(listing.title, 'annonce')}/${listing.id}/`,
      })),
    });
  }

  if (intent.key === 'services' && activation.eligible) {
    graph.push({
      '@type': 'ItemList',
      '@id': `${canonical}#prestataires`,
      name: `Prestataires ${service.serviceTitle} à ${city.name}`,
      itemListElement: activation.profilePreviews.map((profile, index) => ({
        '@type': 'ListItem',
        position: index + 1,
        name: profile.companyName,
        url: `${registry.baseUrl}/prestataires/${publicSlug(profile.companyName, 'prestataire')}/${profile.publicId}/`,
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
      <span class="public-kicker">${escapeHtml(city.territory)}${postalLabel ? ` · ${escapeHtml(postalLabel)}` : ''}</span>
      <h1>${escapeHtml(h1)}</h1>
      <p class="public-lead">${escapeHtml(city.localIntro)} ${escapeHtml(audienceCopy)}</p>
      <section class="public-grid" aria-label="Informations locales">
        <article><h2>Recherche locale précise</h2><p>La page associe une catégorie de service, une ville et une intention de recherche afin d’éviter les pages génériques ou dupliquées.</p></article>
        <article><h2>Données réelles avant indexation</h2><p>L’indexation n’est activée qu’après atteinte du seuil minimal de signaux réels, récents et adaptés à l’intention de recherche.</p></article>
        <article><h2>Échange direct</h2><p>iliprestō facilite la mise en relation. La plateforme n’est ni employeur, ni agence d’intérim, et ne garantit ni mission, ni revenu, ni délai de réponse.</p></article>
      </section>
      ${localStatsSection}
      ${localMarket ? `<section aria-label="Contexte local"><h2>${escapeHtml(service.serviceTitle)} à ${escapeHtml(city.name)}</h2><p>${escapeHtml(localMarket)}</p></section>` : ''}
      ${profileSection}
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


function hubRoute(intent, service = null) {
  return service
    ? `${intent.routePrefix}/${service.slug}/`
    : `${intent.routePrefix}/`;
}

function eligibleCitiesFor(intent, service) {
  return registry.cities.filter((city) =>
    activationFor(intent, pageKey(intent, service, city), city).eligible);
}

function hubTitle(intent, service = null) {
  if (!service) {
    return intent.key === 'services'
      ? 'Services près de chez vous | iliprestō'
      : 'Missions de services près de chez vous | iliprestō';
  }
  return intent.key === 'services'
    ? `${service.serviceTitle} près de chez vous | iliprestō`
    : `Missions ${shortMissionLabel(service)} près de chez vous | iliprestō`;
}

function hubDescription(intent, service = null) {
  if (!service) {
    return intent.key === 'services'
      ? 'Explorez les catégories de services sur iliprestō et accédez aux pages locales activées uniquement lorsque des profils publics réels et récents sont disponibles.'
      : 'Explorez les catégories de missions sur iliprestō et accédez aux pages locales activées uniquement lorsque des annonces publiques réelles et récentes sont disponibles.';
  }
  return intent.key === 'services'
    ? `Explorez ${service.serviceLower} sur iliprestō et consultez uniquement les pages locales disposant de profils publics réels, qualifiés et récents.`
    : `Explorez les missions ${shortMissionLabel(service)} sur iliprestō et consultez uniquement les pages locales disposant d’annonces publiques réelles et récentes.`;
}

function renderIntentHub(intent) {
  const route = hubRoute(intent);
  const canonical = `${registry.baseUrl}${route}`;
  const title = hubTitle(intent);
  const description = hubDescription(intent);
  const serviceRows = registry.services.map((service) => {
    const childRoute = hubRoute(intent, service);
    const activeCities = eligibleCitiesFor(intent, service).length;
    return `<li><a href="${escapeHtml(childRoute)}">${escapeHtml(service.serviceTitle)}</a><span> — ${activeCities > 0 ? `${activeCities} zone${activeCities > 1 ? 's' : ''} locale${activeCities > 1 ? 's' : ''} active${activeCities > 1 ? 's' : ''}` : 'pages locales en préparation'}</span></li>`;
  }).join('');
  const eligible = registry.services.some((service) => eligibleCitiesFor(intent, service).length > 0);
  const robots = eligible ? registry.activationGate.activeRobots : registry.activationGate.inactiveRobots;
  const counterpart = registry.intents.find((candidate) => candidate.key !== intent.key);
  const graph = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'CollectionPage',
        '@id': `${canonical}#webpage`,
        url: canonical,
        name: title,
        description,
        inLanguage: 'fr-FR',
        isPartOf: {'@id': `${registry.baseUrl}/#website`},
        publisher: {'@id': `${registry.baseUrl}/#organization`},
        mainEntity: {'@id': `${canonical}#categories`},
        breadcrumb: {'@id': `${canonical}#breadcrumb`},
      },
      {
        '@type': 'BreadcrumbList',
        '@id': `${canonical}#breadcrumb`,
        itemListElement: [
          {'@type': 'ListItem', position: 1, name: 'Accueil', item: `${registry.baseUrl}/`},
          {'@type': 'ListItem', position: 2, name: intent.key === 'services' ? 'Services' : 'Missions', item: canonical},
        ],
      },
      {
        '@type': 'ItemList',
        '@id': `${canonical}#categories`,
        name: intent.key === 'services' ? 'Catégories de services' : 'Catégories de missions',
        numberOfItems: registry.services.length,
        itemListElement: registry.services.map((service, index) => ({
          '@type': 'ListItem',
          position: index + 1,
          name: service.serviceTitle,
          url: `${registry.baseUrl}${hubRoute(intent, service)}`,
        })),
      },
    ],
  };
  const lead = intent.key === 'services'
    ? 'Choisissez un type de service. Les pages locales ne sont ouvertes à l’indexation que lorsqu’elles reposent sur des profils publics réels, qualifiés et récents.'
    : 'Choisissez un type de mission. Les pages locales ne sont ouvertes à l’indexation que lorsqu’elles reposent sur des annonces publiques réelles, complètes et récentes.';

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
  <link rel="stylesheet" href="/public-pages.css">
  <title>${escapeHtml(title)}</title>
  <script type="application/ld+json">${escapeJson(graph)}</script>
</head>
<body class="public-page">
  <div class="public-shell">
    <header><a class="public-brand" href="/" aria-label="Accueil iliprestō"><img src="/assets/assets/images/ilipresto_splash_logo.webp" alt="Logo iliprestō" width="54" height="54"><span>iliprestō</span></a></header>
    <nav class="public-breadcrumb" aria-label="Fil d’Ariane"><ol><li><a href="/">Accueil</a></li><li aria-current="page">${intent.key === 'services' ? 'Services' : 'Missions'}</li></ol></nav>
    <main class="public-card">
      <span class="public-kicker">France · Guadeloupe · Martinique · Guyane</span>
      <h1>${intent.key === 'services' ? 'Services près de chez vous' : 'Missions de services près de chez vous'}</h1>
      <p class="public-lead">${escapeHtml(lead)}</p>
      <section aria-label="Catégories"><h2>Explorer les catégories</h2><ul>${serviceRows}</ul></section>
      <p class="public-status">${eligible ? 'Ce hub référence au moins une page locale appuyée sur des données de production suffisantes.' : 'Ce hub reste hors index tant qu’aucune page locale ne dispose de signaux de production suffisants.'}</p>
      <nav class="public-links" aria-label="Explorer iliprestō">
        <a href="${escapeHtml(hubRoute(counterpart))}">${counterpart.key === 'services' ? 'Voir les services' : 'Voir les missions'}</a>
        <a href="/guadeloupe">Guadeloupe</a>
        <a href="/martinique">Martinique</a>
        <a href="/guyane">Guyane</a>
        <a href="/trouver-une-personne-disponible/">Trouver une personne disponible</a>
        <a href="/guides/comment-fonctionne-ilipresto">Comment fonctionne iliprestō ?</a>
      </nav>
    </main>
    <footer class="public-footer"><span>ilipresto.fr</span><a href="/mentions-legales">Mentions légales</a><a href="/confidentialite">Confidentialité</a><a href="/cgu">Conditions d’utilisation</a></footer>
  </div>
</body>
</html>`;
}

function renderServiceHub(intent, service) {
  const route = hubRoute(intent, service);
  const canonical = `${registry.baseUrl}${route}`;
  const title = hubTitle(intent, service);
  const description = hubDescription(intent, service);
  const activeCities = eligibleCitiesFor(intent, service);
  const eligible = activeCities.length > 0;
  const robots = eligible ? registry.activationGate.activeRobots : registry.activationGate.inactiveRobots;
  const cityItems = activeCities.length > 0
    ? activeCities.map((city) =>
      `<li><a href="${escapeHtml(routeFor(intent, service, city))}">${escapeHtml(service.serviceTitle)} à ${escapeHtml(city.name)}</a> — ${escapeHtml(city.territory)}</li>`).join('')
    : '<li>Aucune page locale n’est encore indexable pour cette catégorie.</li>';
  const counterpart = registry.intents.find((candidate) => candidate.key !== intent.key);
  const graph = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'CollectionPage',
        '@id': `${canonical}#webpage`,
        url: canonical,
        name: title,
        description,
        inLanguage: 'fr-FR',
        isPartOf: {'@id': `${registry.baseUrl}/#website`},
        publisher: {'@id': `${registry.baseUrl}/#organization`},
        mainEntity: {'@id': `${canonical}#zones`},
        breadcrumb: {'@id': `${canonical}#breadcrumb`},
      },
      {
        '@type': 'BreadcrumbList',
        '@id': `${canonical}#breadcrumb`,
        itemListElement: [
          {'@type': 'ListItem', position: 1, name: 'Accueil', item: `${registry.baseUrl}/`},
          {'@type': 'ListItem', position: 2, name: intent.key === 'services' ? 'Services' : 'Missions', item: `${registry.baseUrl}${hubRoute(intent)}`},
          {'@type': 'ListItem', position: 3, name: service.serviceTitle, item: canonical},
        ],
      },
      {
        '@type': 'ItemList',
        '@id': `${canonical}#zones`,
        name: `${service.serviceTitle} — zones locales disponibles`,
        numberOfItems: activeCities.length,
        itemListElement: activeCities.map((city, index) => ({
          '@type': 'ListItem',
          position: index + 1,
          name: `${service.serviceTitle} à ${city.name}`,
          url: `${registry.baseUrl}${routeFor(intent, service, city)}`,
        })),
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
  <link rel="stylesheet" href="/public-pages.css">
  <title>${escapeHtml(title)}</title>
  <script type="application/ld+json">${escapeJson(graph)}</script>
</head>
<body class="public-page">
  <div class="public-shell">
    <header><a class="public-brand" href="/" aria-label="Accueil iliprestō"><img src="/assets/assets/images/ilipresto_splash_logo.webp" alt="Logo iliprestō" width="54" height="54"><span>iliprestō</span></a></header>
    <nav class="public-breadcrumb" aria-label="Fil d’Ariane"><ol><li><a href="/">Accueil</a></li><li><a href="${escapeHtml(hubRoute(intent))}">${intent.key === 'services' ? 'Services' : 'Missions'}</a></li><li aria-current="page">${escapeHtml(service.serviceTitle)}</li></ol></nav>
    <main class="public-card">
      <span class="public-kicker">${intent.key === 'services' ? 'Trouver une compétence' : 'Trouver un besoin local'}</span>
      <h1>${intent.key === 'services' ? escapeHtml(service.serviceTitle) + ' près de chez vous' : 'Missions ' + escapeHtml(shortMissionLabel(service)) + ' près de chez vous'}</h1>
      <p class="public-lead">${escapeHtml(description)}</p>
      <section aria-label="Zones locales"><h2>Pages locales disponibles</h2><ul>${cityItems}</ul></section>
      <h2>Recherches associées</h2>
      <ul>${service.keywords.map((keyword) => `<li>${escapeHtml(keyword)}</li>`).join('')}</ul>
      <p class="public-status">${eligible ? `${activeCities.length} page${activeCities.length > 1 ? 's' : ''} locale${activeCities.length > 1 ? 's' : ''} dispose${activeCities.length > 1 ? 'nt' : ''} de signaux réels suffisants pour l’indexation.` : 'Cette catégorie reste hors index tant qu’aucune zone locale ne dispose de signaux réels suffisants.'}</p>
      <nav class="public-links" aria-label="Explorer iliprestō">
        <a href="${escapeHtml(hubRoute(intent))}">Toutes les catégories</a>
        <a href="${escapeHtml(hubRoute(counterpart, service))}">${counterpart.key === 'services' ? 'Chercher ce service' : 'Voir les missions correspondantes'}</a>
        <a href="/guadeloupe">Guadeloupe</a>
        <a href="/martinique">Martinique</a>
        <a href="/guyane">Guyane</a>
        <a href="/guides/comment-fonctionne-ilipresto">Comment fonctionne iliprestō ?</a>
        <a href="/guides/creer-micro-entreprise-services/">Créer une activité de services</a>
      </nav>
    </main>
    <footer class="public-footer"><span>ilipresto.fr — ${escapeHtml(service.serviceTitle)}</span><a href="/mentions-legales">Mentions légales</a><a href="/confidentialite">Confidentialité</a><a href="/cgu">Conditions d’utilisation</a></footer>
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

for (const intent of registry.intents) {
  const intentRoute = hubRoute(intent);
  const intentOutput = path.join('web', intentRoute, 'index.html');
  fs.mkdirSync(path.dirname(intentOutput), {recursive: true});
  fs.writeFileSync(intentOutput, renderIntentHub(intent));
  const intentEligible = registry.services.some((service) => eligibleCitiesFor(intent, service).length > 0);
  generated.push({route: intentRoute, eligible: intentEligible});

  for (const service of registry.services) {
    const serviceRoute = hubRoute(intent, service);
    const serviceOutput = path.join('web', serviceRoute, 'index.html');
    fs.mkdirSync(path.dirname(serviceOutput), {recursive: true});
    fs.writeFileSync(serviceOutput, renderServiceHub(intent, service));
    generated.push({route: serviceRoute, eligible: eligibleCitiesFor(intent, service).length > 0});
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

console.log(`SEO local + hubs: ${generated.length} pages générées, ${generated.filter((page) => page.eligible).length} indexables.`);
