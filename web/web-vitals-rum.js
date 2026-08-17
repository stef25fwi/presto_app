(function () {
  'use strict';

  if (window.__ILIPRESTO_WEB_VITALS_RUM__) return;
  window.__ILIPRESTO_WEB_VITALS_RUM__ = true;

  const optOutKey = 'ilipresto-cwv-optout';
  const observers = [];
  let reportingDisabled = false;
  let inpFlushTimer = null;

  function hasPersistentOptOut() {
    try {
      return window.localStorage.getItem(optOutKey) === '1';
    } catch (_) {
      return false;
    }
  }

  window.iliprestoDisableWebVitals = function () {
    reportingDisabled = true;
    if (inpFlushTimer !== null) {
      window.clearTimeout(inpFlushTimer);
      inpFlushTimer = null;
    }
    try {
      window.localStorage.setItem(optOutKey, '1');
    } catch (_) {
      // Le refus reste actif pour la page courante si le stockage est bloqué.
    }
    observers.forEach(function (observer) { observer.disconnect(); });
  };

  if (!('PerformanceObserver' in window)) return;
  if (navigator.webdriver === true || /HeadlessChrome|Lighthouse/i.test(navigator.userAgent)) return;
  if (navigator.doNotTrack === '1' || navigator.globalPrivacyControl === true) return;
  if (hasPersistentOptOut()) return;

  const endpoint = 'https://europe-west1-presto-app-74abe.cloudfunctions.net/collectWebVitals';
  const pageViewId = createPageViewId();
  const route = normalizeRoute(window.location.pathname);
  const deviceCategory = window.matchMedia('(max-width: 767px)').matches
      ? 'mobile'
      : 'desktop';
  const navigationEntry = performance.getEntriesByType('navigation')[0];
  const navigationType = navigationEntry && navigationEntry.type
      ? String(navigationEntry.type)
      : 'navigate';
  let releaseSha = 'unknown';
  let lcpValue = null;
  let clsValue = 0;
  let clsSessionValue = 0;
  let clsSessionStart = 0;
  let clsSessionEnd = 0;
  const interactions = new Map();
  const lastSent = new Map();

  function createPageViewId() {
    if (window.crypto && typeof window.crypto.randomUUID === 'function') {
      return window.crypto.randomUUID().replace(/-/g, '');
    }
    const bytes = new Uint8Array(16);
    if (window.crypto && typeof window.crypto.getRandomValues === 'function') {
      window.crypto.getRandomValues(bytes);
      return Array.from(bytes, function (value) {
        return value.toString(16).padStart(2, '0');
      }).join('');
    }
    return Math.random().toString(36).slice(2) + Date.now().toString(36);
  }

  function normalizeRoute(rawValue) {
    let value = String(rawValue || '/').split(/[?#]/, 1)[0] || '/';
    if (!value.startsWith('/')) value = '/' + value;
    if (value.length > 1 && value.endsWith('/')) value = value.slice(0, -1);
    return value.split('/').map(function (segment) {
      if (/^[0-9]{5,}$/.test(segment)) return ':id';
      if (/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(segment)) return ':id';
      if (/^[A-Za-z0-9_-]{24,}$/.test(segment)) return ':id';
      return segment.slice(0, 80);
    }).join('/').slice(0, 180) || '/';
  }

  function metricRating(name, value) {
    const good = name === 'LCP' ? 2500 : name === 'INP' ? 200 : 0.1;
    const poor = name === 'LCP' ? 4000 : name === 'INP' ? 500 : 0.25;
    if (value <= good) return 'good';
    if (value <= poor) return 'needs-improvement';
    return 'poor';
  }

  function sendMetric(name, value) {
    if (reportingDisabled || !Number.isFinite(value) || value < 0) return;
    const normalizedValue = name === 'CLS'
        ? Math.round(value * 10000) / 10000
        : Math.round(value);
    if (lastSent.get(name) === normalizedValue) return;
    lastSent.set(name, normalizedValue);

    const payload = JSON.stringify({
      schemaVersion: 1,
      metric: name,
      value: normalizedValue,
      delta: normalizedValue,
      rating: metricRating(name, normalizedValue),
      route: route,
      deviceCategory: deviceCategory,
      navigationType: navigationType,
      releaseSha: releaseSha,
      pageViewId: pageViewId,
      collectedAtClient: new Date().toISOString(),
    });

    const body = new Blob([payload], { type: 'text/plain;charset=UTF-8' });
    if (navigator.sendBeacon && navigator.sendBeacon(endpoint, body)) return;
    fetch(endpoint, {
      method: 'POST',
      body: payload,
      headers: { 'Content-Type': 'text/plain;charset=UTF-8' },
      credentials: 'omit',
      keepalive: true,
      cache: 'no-store',
    }).catch(function () {});
  }

  function currentInp() {
    if (interactions.size === 0) return null;
    const values = Array.from(interactions.values()).sort(function (a, b) {
      return b - a;
    });
    const ignoredWorstInteractions = Math.floor(interactions.size / 50);
    return values[Math.min(ignoredWorstInteractions, values.length - 1)] || null;
  }

  function scheduleInpFlush() {
    if (inpFlushTimer !== null) window.clearTimeout(inpFlushTimer);
    inpFlushTimer = window.setTimeout(function () {
      inpFlushTimer = null;
      const inpValue = currentInp();
      if (inpValue !== null) sendMetric('INP', inpValue);
    }, 250);
  }

  function flush() {
    if (lcpValue !== null) sendMetric('LCP', lcpValue);
    sendMetric('CLS', clsValue);
    const inpValue = currentInp();
    if (inpValue !== null) sendMetric('INP', inpValue);
  }

  function observe(type, callback, options) {
    try {
      const observer = new PerformanceObserver(callback);
      observer.observe(Object.assign({ type: type, buffered: true }, options || {}));
      observers.push(observer);
    } catch (_) {
      // Certains navigateurs ne prennent pas encore en charge tous les types.
    }
  }

  observe('largest-contentful-paint', function (list) {
    const entries = list.getEntries();
    const entry = entries[entries.length - 1];
    if (entry) lcpValue = entry.startTime;
  });

  observe('layout-shift', function (list) {
    list.getEntries().forEach(function (entry) {
      if (entry.hadRecentInput) return;
      const startTime = entry.startTime;
      if (
        clsSessionStart === 0 ||
        startTime - clsSessionEnd > 1000 ||
        startTime - clsSessionStart > 5000
      ) {
        clsSessionStart = startTime;
        clsSessionEnd = startTime;
        clsSessionValue = entry.value;
      } else {
        clsSessionEnd = startTime;
        clsSessionValue += entry.value;
      }
      clsValue = Math.max(clsValue, clsSessionValue);
    });
  });

  observe('event', function (list) {
    let observedInteraction = false;
    list.getEntries().forEach(function (entry) {
      const interactionId = Number(entry.interactionId || 0);
      if (interactionId <= 0) return;
      const duration = Number(entry.duration || 0);
      const previous = interactions.get(interactionId) || 0;
      if (duration > previous) interactions.set(interactionId, duration);
      observedInteraction = true;
    });
    if (observedInteraction) scheduleInpFlush();
  }, { durationThreshold: 16 });

  window.addEventListener('ilipresto-consent-updated', function (event) {
    const detail = event && event.detail;
    if (detail && detail.analyticsAllowed === false) {
      window.iliprestoDisableWebVitals();
    }
  });

  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'hidden') flush();
  });
  window.addEventListener('pagehide', flush);

  fetch('/version.json', { cache: 'no-store', credentials: 'omit' })
    .then(function (response) { return response.ok ? response.json() : null; })
    .then(function (version) {
      if (!version || typeof version !== 'object') return;
      releaseSha = String(
        version.gitCommit || version.commit || version.sha || version.gitSha || 'unknown'
      ).slice(0, 64);
    })
    .catch(function () {});

  window.iliprestoWebVitalsRum = Object.freeze({ flush: flush });
})();
