{{flutter_js}}
{{flutter_build_config}}

(function () {
  const params = new URLSearchParams(window.location.search);
  const host = window.location.hostname;

  const prodHosts = new Set([
    'ilipresto.fr',
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