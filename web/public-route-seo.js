(function () {
  'use strict';

  const baseUrl = 'https://ilipresto.fr';
  const organizationId = baseUrl + '/#organization';
  const websiteId = baseUrl + '/#website';
  const logoId = baseUrl + '/#logo';
  const pageLastModified = '2026-08-05T23:00:00Z';
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
      lead: 'Cette page présente les traitements de données, leurs finalités, les durées de conservation et les droits des utilisateurs.',
      audienceMeasurement: true
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

  function injectBrandTheme() {
    if (document.querySelector('style[data-ilipresto-brand-theme]')) return;

    const style = document.createElement('style');
    style.dataset.iliprestoBrandTheme = 'public-pages';
    style.textContent = [
      ':root,html,body{background:#fff!important}',
      '#prelaunch-seo-shell{background:#f7f9fc!important;color:#12345b!important}',
      '.prelaunch-card{background:#fff!important;border-color:#e3e8ef!important;box-shadow:0 16px 36px rgba(18,52,91,.08)!important}',
      '.prelaunch-badge{color:#175db8!important;background:#eef4ff!important;border:1px solid rgba(26,115,232,.18)!important}',
      '.prelaunch-card h1{color:#12345b!important}',
      '.prelaunch-card p{color:#526477!important}',
      '.prelaunch-features li{color:#33485e!important;background:#f8fafc!important;border-color:#e3e8ef!important}',
      '.prelaunch-message{color:#6f370f!important;background:#fff!important;border:1px solid rgba(255,102,0,.4)!important;border-left:4px solid #ff6600!important;border-radius:16px!important}',
      '.prelaunch-public-links a{color:#1a73e8!important}',
      '.prelaunch-public-links a:focus-visible{outline:3px solid rgba(26,115,232,.35)!important;outline-offset:4px!important;border-radius:6px!important}',
      'html[data-public-prelaunch="true"] .prelaunch-public-links a[href="/guadeloupe"],html[data-public-prelaunch="true"] .prelaunch-public-links a[href="/martinique"],html[data-public-prelaunch="true"] .prelaunch-public-links a[href="/guyane"]{display:none!important}',
      '.prelaunch-domain{color:#6a7785!important}',
      '.audience-measurement{margin:24px 0;padding:18px;text-align:left;border:1px solid #dbe5f0;border-radius:16px;background:#f8fbff}',
      '.audience-measurement h2{margin:0 0 10px;color:#12345b;font-size:1.15rem}',
      '.audience-measurement p{margin:0 0 12px!important;font-size:.95rem!important}',
      '.audience-measurement button{border:0;border-radius:12px;padding:11px 14px;background:#12345b;color:#fff;font:inherit;font-weight:700;cursor:pointer}',
      '.audience-measurement button:focus-visible{outline:3px solid rgba(26,115,232,.35);outline-offset:3px}',
      '.audience-measurement-status{margin-top:10px!important;color:#33485e!important;font-weight:700}'
    ].join('');
    document.head.appendChild(style);
  }

  function removePrelaunchRegionalLinks() {
    document.querySelectorAll([
      '#prelaunch-seo-shell .prelaunch-public-links a[href="/guadeloupe"]',
      '#prelaunch-seo-shell .prelaunch-public-links a[href="/martinique"]',
      '#prelaunch-seo-shell .prelaunch-public-links a[href="/guyane"]'
    ].join(',')).forEach(function (link) {
      link.remove();
    });
  }

  const path = normalizePath(window.location.pathname);
  injectBrandTheme();

  const publicHosts = new Set([
    'ilipresto.fr',
    'www.ilipresto.fr',
    'ilipresto.web.app',
    'ilipresto.firebaseapp.com',
    'presto-app-74abe.web.app',
    'presto-app-74abe.firebaseapp.com'
  ]);
  const isPublicPrelaunch = path === '/' && publicHosts.has(window.location.hostname.toLowerCase());

  if (isPublicPrelaunch) {
    document.documentElement.dataset.publicPrelaunch = 'true';
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', removePrelaunchRegionalLinks, {once: true});
    } else {
      removePrelaunchRegionalLinks();
    }

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

    const audienceMeasurement = page.audienceMeasurement
      ? [
          '<section class="audience-measurement" aria-labelledby="audience-measurement-title">',
          '<h2 id="audience-measurement-title">Mesure d’audience technique</h2>',
          '<p>iliprestō mesure uniquement LCP, INP et CLS pour améliorer la rapidité et la stabilité des pages. Aucun nom, email, compte, cookie publicitaire ni adresse IP n’est conservé. Les routes contenant un identifiant sont anonymisées et les échantillons sont supprimés après 35 jours.</p>',
          '<button id="disable-cwv" type="button">Refuser la mesure d’audience technique</button>',
          '<p id="audience-measurement-status" class="audience-measurement-status" role="status" aria-live="polite"></p>',
          '</section>'
        ].join('')
      : '';

    main.innerHTML = [
      '<nav class="public-breadcrumb" aria-label="Fil d’Ariane">',
      '<ol><li><a href="/">Accueil</a></li><li aria-current="page">' + page.h1 + '</li></ol>',
      '</nav>',
      '<div class="prelaunch-badge">Information publique</div>',
      '<h1>' + page.h1 + '</h1>',
      '<p>' + page.lead + '</p>',
      audienceMeasurement,
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

    const disableButton = document.getElementById('disable-cwv');
    const status = document.getElementById('audience-measurement-status');
    if (disableButton && status) {
      let alreadyDisabled = false;
      try {
        alreadyDisabled = window.localStorage.getItem('ilipresto-cwv-optout') === '1';
      } catch (_) {}
      if (alreadyDisabled) {
        disableButton.disabled = true;
        status.textContent = 'La mesure d’audience technique est déjà désactivée sur ce navigateur.';
      }
      disableButton.addEventListener('click', function () {
        if (typeof window.iliprestoDisableWebVitals === 'function') {
          window.iliprestoDisableWebVitals();
        } else {
          try {
            window.localStorage.setItem('ilipresto-cwv-optout', '1');
          } catch (_) {}
        }
        disableButton.disabled = true;
        status.textContent = 'La mesure d’audience technique est désactivée sur ce navigateur.';
      });
    }
  });
})();
