(function () {
  'use strict';

  const baseUrl = 'https://ilipresto.fr';
  const organizationId = baseUrl + '/#organization';
  const websiteId = baseUrl + '/#website';
  const logoId = baseUrl + '/#logo';
  const pageLastModified = '2026-08-03T23:30:00Z';
  const pages = {
    '/mentions-legales': {
      title: 'Mentions légales | iliprestō',
      description: 'Consultez l’identité de l’éditeur, l’hébergement et les informations légales applicables à la plateforme nationale iliprestō.',
      h1: 'Mentions légales d’iliprestō',
      lead: 'Retrouvez l’identité de l’éditeur, le directeur de publication, l’hébergement et les informations qui encadrent la plateforme.'
    },
    '/confidentialite': {
      title: 'Politique de confidentialité | iliprestō',
      description: 'Découvrez comment iliprestō collecte, protège, utilise et conserve les données personnelles de ses utilisateurs partout en France.',
      h1: 'Politique de confidentialité d’iliprestō',
      lead: 'Cette page présente les traitements de données, leurs finalités, les durées de conservation et les droits des utilisateurs.'
    },
    '/cgu': {
      title: 'Conditions générales d’utilisation | iliprestō',
      description: 'Consultez les conditions générales d’utilisation qui encadrent l’accès et l’usage de la plateforme nationale iliprestō.',
      h1: 'Conditions générales d’utilisation',
      lead: 'Ces conditions définissent les règles d’accès, de publication, d’échange et de responsabilité applicables à iliprestō.'
    },
    '/suppression-compte': {
      title: 'Supprimer votre compte iliprestō',
      description: 'Consultez les procédures pour supprimer votre compte iliprestō et connaître les données supprimées ou légalement conservées.',
      h1: 'Supprimer votre compte iliprestō',
      lead: 'Découvrez les démarches disponibles depuis l’application ou par contact direct, ainsi que les catégories de données concernées.'
    }
  };

  function normalizePath(value) {
    let path = String(value || '').trim() || '/';
    if (!path.startsWith('/')) path = '/' + path;
    if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
    return path;
  }

  const path = normalizePath(window.location.pathname);

  const publicHosts = new Set([
    'ilipresto.fr',
    'www.ilipresto.fr',
    'ilipresto.web.app',
    'ilipresto.firebaseapp.com',
    'presto-app-74abe.web.app',
    'presto-app-74abe.firebaseapp.com'
  ]);

  if (path === '/' && publicHosts.has(window.location.hostname.toLowerCase())) {
    window.addEventListener('flutter-first-frame', function (event) {
      event.stopImmediatePropagation();

      const shell = document.getElementById('prelaunch-seo-shell');
      if (!shell) return;

      shell.style.transition = 'opacity 180ms ease-out';
      shell.style.willChange = 'opacity';

      window.setTimeout(function () {
        shell.style.opacity = '0';
        window.setTimeout(function () {
          shell.remove();
        }, 200);
      }, 700);
    }, true);
  }

  const page = pages[path];
  if (!page) return;

  const canonical = baseUrl + path;
  document.title = page.title;
  document.documentElement.dataset.publicSeoRoute = path;

  function setMeta(selector, attribute, value) {
    const element = document.querySelector(selector);
    if (element) element.setAttribute(attribute, value);
  }

  setMeta('meta[name="description"]', 'content', page.description);
  setMeta('link[rel="canonical"]', 'href', canonical);
  setMeta('meta[property="og:url"]', 'content', canonical);
  setMeta('meta[property="og:title"]', 'content', page.title);
  setMeta('meta[property="og:description"]', 'content', page.description);
  setMeta('meta[name="twitter:title"]', 'content', page.title);
  setMeta('meta[name="twitter:description"]', 'content', page.description);

  const structuredData = document.createElement('script');
  structuredData.type = 'application/ld+json';
  structuredData.dataset.iliprestoStructuredData = 'legal-page';
  structuredData.textContent = JSON.stringify({
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'WebPage',
        '@id': canonical + '#webpage',
        url: canonical,
        name: page.title,
        description: page.description,
        dateModified: pageLastModified,
        inLanguage: 'fr-FR',
        isPartOf: {'@id': websiteId},
        publisher: {'@id': organizationId},
        about: {'@id': organizationId},
        primaryImageOfPage: {'@id': logoId},
        breadcrumb: {'@id': canonical + '#breadcrumb'}
      },
      {
        '@type': 'BreadcrumbList',
        '@id': canonical + '#breadcrumb',
        itemListElement: [
          {'@type': 'ListItem', position: 1, name: 'Accueil', item: baseUrl + '/'},
          {'@type': 'ListItem', position: 2, name: page.h1, item: canonical}
        ]
      }
    ]
  });
  document.head.appendChild(structuredData);

  document.addEventListener('DOMContentLoaded', function () {
    const main = document.querySelector('#prelaunch-seo-shell .prelaunch-card');
    if (!main) return;

    main.innerHTML = [
      '<nav class="public-breadcrumb" aria-label="Fil d’Ariane">',
      '<ol><li><a href="/">Accueil</a></li><li aria-current="page">' + page.h1 + '</li></ol>',
      '</nav>',
      '<div class="prelaunch-badge">Information publique</div>',
      '<h1>' + page.h1 + '</h1>',
      '<p>' + page.lead + '</p>',
      '<nav class="prelaunch-public-links" aria-label="Pages publiques iliprestō">',
      '<a href="/">Accueil</a>',
      '<a href="/a-propos">À propos</a>',
      '<a href="/guides/comment-fonctionne-ilipresto">Guide d’utilisation</a>',
      '<a href="/guadeloupe">Guadeloupe</a>',
      '<a href="/martinique">Martinique</a>',
      '<a href="/guyane">Guyane</a>',
      '<a href="/mentions-legales">Mentions légales</a>',
      '<a href="/confidentialite">Confidentialité</a>',
      '<a href="/cgu">CGU</a>',
      '<a href="/suppression-compte">Suppression du compte</a>',
      '</nav>'
    ].join('');
  });
})();
