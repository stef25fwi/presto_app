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
  const host = window.location.hostname;

  const prodHosts = new Set([
    'ilipresto.fr',
    'www.ilipresto.fr',
    'ilipresto.web.app',
    'ilipresto.firebaseapp.com',
    'presto-app-74abe.web.app',
    'presto-app-74abe.firebaseapp.com',
  ]);

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
  });
})();
