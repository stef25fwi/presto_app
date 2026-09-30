{{flutter_js}}
{{flutter_build_config}}

(function () {
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () {
    window.dataLayer.push(arguments);
  };

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

  const useFlutterPrelaunchOnly =
      normalizedPath === '/' && prodHosts.has(host);
  let prelaunchTransitionShell = null;
  let flutterStartRequested = false;

  // Old session flags never authorize access to the public application.
  try {
    window.sessionStorage.removeItem('ilipresto-prelaunch-access');
  } catch (_) {
    // Storage may be unavailable in private browsing; access stays closed.
  }

  function applyPrelaunchAccessibilityFixes() {
    if (document.getElementById('ilipresto-prelaunch-a11y-fixes')) return;
    const style = document.createElement('style');
    style.id = 'ilipresto-prelaunch-a11y-fixes';
    style.textContent = [
      '.prelaunch-brand-name{color:#c64700!important}',
      '.prelaunch-domain{color:#5f6b78!important}',
    ].join('');
    document.head.appendChild(style);
  }

  function getPrelaunchSeoShell() {
    return document.getElementById('prelaunch-seo-shell');
  }

  function createPrelaunchTransitionShell(shell) {
    if (!useFlutterPrelaunchOnly || prelaunchTransitionShell || !shell) return;

    prelaunchTransitionShell = shell.cloneNode(true);
    prelaunchTransitionShell.id = 'prelaunch-transition-shell';
    prelaunchTransitionShell.setAttribute('aria-hidden', 'true');
    prelaunchTransitionShell.style.pointerEvents = 'none';
    prelaunchTransitionShell.style.zIndex = '2147483646';

    const shellStyle = window.getComputedStyle(shell);
    prelaunchTransitionShell.style.position = 'fixed';
    prelaunchTransitionShell.style.inset = '0';
    prelaunchTransitionShell.style.overflow = 'auto';
    prelaunchTransitionShell.style.boxSizing = 'border-box';
    prelaunchTransitionShell.style.padding = shellStyle.padding;
    prelaunchTransitionShell.style.background = shellStyle.background;

    prelaunchTransitionShell.dataset.flutterLoading = 'true';
    document.body.appendChild(prelaunchTransitionShell);
  }

  function removePrelaunchTransitionShell() {
    if (!prelaunchTransitionShell) return;
    prelaunchTransitionShell.remove();
    prelaunchTransitionShell = null;
  }

  function preparePrelaunchSeoShellForFlutter() {
    const shell = getPrelaunchSeoShell();
    if (!shell || shell.hidden) return;

    if (useFlutterPrelaunchOnly) {
      createPrelaunchTransitionShell(shell);
      shell.style.visibility = 'hidden';
      shell.style.pointerEvents = 'none';
      shell.setAttribute('aria-hidden', 'true');
      shell.dataset.flutterLoading = 'true';
      return;
    }

    const card = shell.querySelector('.prelaunch-card');
    const domain = shell.querySelector('.prelaunch-domain');
    const brand = shell.querySelector('.prelaunch-brand');

    if (card) card.hidden = true;
    if (domain) domain.hidden = true;
    if (brand) brand.style.marginBottom = '0';

    shell.setAttribute('aria-hidden', 'true');
    shell.dataset.flutterLoading = 'true';
  }

  function removePrelaunchSeoShell() {
    const shell = getPrelaunchSeoShell();
    if (shell) shell.remove();

    if (!useFlutterPrelaunchOnly) {
      removePrelaunchTransitionShell();
    }
  }

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

  function startFlutterApplication() {
    if (flutterStartRequested) return;
    flutterStartRequested = true;

    preparePrelaunchSeoShellForFlutter();
    window.addEventListener('flutter-first-frame', removePrelaunchSeoShell, {
      once: true,
    });

    _flutter.loader.load({
      serviceWorkerSettings: disableServiceWorker
          ? undefined
          : {
              serviceWorkerVersion: {{flutter_service_worker_version}},
            },
      onEntrypointLoaded: async function (engineInitializer) {
        const appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
        window.requestAnimationFrame(removePrelaunchSeoShell);
      },
    });
  }

  applyPrelaunchAccessibilityFixes();

  // Keep the public landing static. Preview hosts still start Flutter;
  // public deep links are gated again by PublicPrelaunchEntryMode in Dart.
  if (useFlutterPrelaunchOnly) return;

  startFlutterApplication();
})();
