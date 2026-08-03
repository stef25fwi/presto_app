{{flutter_js}}
{{flutter_build_config}}

(function () {
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () {
    window.dataLayer.push(arguments);
  };

  // Consent Mode v2 must be configured before Firebase/Google tags load.
  window.gtag('consent', 'default', {
    ad_storage: 'denied',
    analytics_storage: 'denied',
    ad_user_data: 'denied',
    ad_personalization: 'denied',
    functionality_storage: 'granted',
    security_storage: 'granted',
    personalization_storage: 'denied',
    wait_for_update: 500,
  });
  window.gtag('set', 'ads_data_redaction', true);
  window.gtag('set', 'url_passthrough', true);

  window.iliprestoConsentUpdate = function (
    analyticsAllowed,
    marketingAllowed
  ) {
    const analytics = analyticsAllowed === true ? 'granted' : 'denied';
    const marketing = marketingAllowed === true ? 'granted' : 'denied';

    window.gtag('consent', 'update', {
      analytics_storage: analytics,
      ad_storage: marketing,
      ad_user_data: marketing,
      ad_personalization: marketing,
      personalization_storage: marketing,
      functionality_storage: 'granted',
      security_storage: 'granted',
    });
    window.gtag('set', 'ads_data_redaction', marketing !== 'granted');

    window.dispatchEvent(
      new CustomEvent('ilipresto-consent-updated', {
        detail: {
          analyticsAllowed: analyticsAllowed === true,
          marketingAllowed: marketingAllowed === true,
        },
      })
    );
  };

  const params = new URLSearchParams(window.location.search);
  const host = window.location.hostname.toLowerCase();
  const normalizedPath = (function () {
    const rawPath = String(window.location.pathname || '/').trim() || '/';
    return rawPath.length > 1 && rawPath.endsWith('/')
        ? rawPath.slice(0, -1)
        : rawPath;
  })();

  const prodHosts = new Set([
    'ilipresto.fr',
    'www.ilipresto.fr',
    'ilipresto.web.app',
    'ilipresto.firebaseapp.com',
    'presto-app-74abe.web.app',
    'presto-app-74abe.firebaseapp.com',
  ]);

  const keepFullPrelaunchShell =
      normalizedPath === '/' && prodHosts.has(host);

  function getPrelaunchSeoShell() {
    return document.getElementById('prelaunch-seo-shell');
  }

  function preparePrelaunchSeoShellForFlutter() {
    const shell = getPrelaunchSeoShell();
    if (!shell || shell.hidden) return;

    // Sur la racine publique, conserver la page complète et stable pendant le
    // chargement de Flutter. Masquer la carte ici produisait la séquence
    // « page complète → fond beige/logo → page complète », perçue comme un bug.
    if (keepFullPrelaunchShell) {
      shell.dataset.flutterLoading = 'true';
      return;
    }

    // Pour les autres routes, conserver le chargement de marque compact.
    const card = shell.querySelector('.prelaunch-card');
    const domain = shell.querySelector('.prelaunch-domain');
    const brand = shell.querySelector('.prelaunch-brand');

    if (card) card.hidden = true;
    if (domain) domain.hidden = true;
    if (brand) brand.style.marginBottom = '0';

    shell.setAttribute('aria-hidden', 'true');
    shell.dataset.flutterLoading = 'true';
  }

  let shellRemovalScheduled = false;

  function removePrelaunchSeoShell() {
    const shell = getPrelaunchSeoShell();
    if (!shell) return;

    if (!keepFullPrelaunchShell) {
      shell.remove();
      return;
    }

    if (shellRemovalScheduled) return;
    shellRemovalScheduled = true;

    // Laisser la page Flutter de pré-lancement stabiliser son rendu sous le
    // shell HTML, puis effectuer une transition imperceptible entre deux écrans
    // visuellement identiques.
    shell.style.transition = 'opacity 180ms ease-out';
    shell.style.willChange = 'opacity';

    window.setTimeout(function () {
      const currentShell = getPrelaunchSeoShell();
      if (!currentShell) return;
      currentShell.style.opacity = '0';
      window.setTimeout(function () {
        const shellToRemove = getPrelaunchSeoShell();
        if (shellToRemove) shellToRemove.remove();
      }, 200);
    }, 700);
  }

  // Run immediately when this same-origin bootstrap is evaluated, well before
  // the Flutter engine and application bundle finish loading.
  preparePrelaunchSeoShellForFlutter();

  window.addEventListener('flutter-first-frame', removePrelaunchSeoShell, {
    once: true,
  });

  const isLocalHost =
      host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0';
  const isPreviewHost =
      host.endsWith('.app.github.dev') ||
      host.endsWith('.github.dev') ||
      host.includes('preview');
  const disableServiceWorker =
      params.get('no_sw') === '1' ||
      isLocalHost ||
      isPreviewHost ||
      !prodHosts.has(host);

  _flutter.loader.load({
    serviceWorkerSettings: disableServiceWorker
        ? undefined
        : {
            serviceWorkerVersion: {{flutter_service_worker_version}},
          },
    onEntrypointLoaded: async function (engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();

      // Fallback fiable si le navigateur ne relaie pas flutter-first-frame.
      // Deux frames laissent Flutter peindre avant de retirer la coquille SEO.
      window.requestAnimationFrame(function () {
        window.requestAnimationFrame(removePrelaunchSeoShell);
      });
    },
  });
})();
