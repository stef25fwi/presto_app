import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errors = new Rate('ilipresto_errors');
const listingsLatency = new Trend('listings_latency', true);

const appBaseUrl = __ENV.APP_BASE_URL || 'https://ilipresto.web.app';
const projectId = __ENV.FIRESTORE_PROJECT_ID || 'presto-app-74abe';
const allowProduction = (__ENV.ALLOW_PRODUCTION_LOAD_TEST || '').toLowerCase() === 'true';

if (appBaseUrl.includes('ilipresto.web.app') && !allowProduction) {
  throw new Error(
    'Production load testing is disabled. Use a staging APP_BASE_URL or set ALLOW_PRODUCTION_LOAD_TEST=true explicitly.',
  );
}

export const options = {
  scenarios: {
    browse_marketplace: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 100 },
        { duration: '3m', target: 500 },
        { duration: '5m', target: 1000 },
        { duration: '5m', target: 1000 },
        { duration: '2m', target: 0 },
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    ilipresto_errors: ['rate<0.01'],
    http_req_duration: ['p(95)<2000'],
    listings_latency: ['p(95)<1500'],
  },
  noConnectionReuse: false,
  userAgent: 'ilipresto-staging-load-test/1.0',
};

function loadWebShell() {
  const response = http.get(appBaseUrl, {
    tags: { flow: 'web_shell' },
  });
  const ok = check(response, {
    'web shell returns 200': (res) => res.status === 200,
    'web shell contains Flutter bootstrap': (res) =>
      res.body.includes('flutter_bootstrap.js') || res.body.includes('main.dart.js'),
  });
  errors.add(!ok);
}

function browseLatestListings() {
  const endpoint =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    '/databases/(default)/documents:runQuery';

  const payload = JSON.stringify({
    structuredQuery: {
      from: [{ collectionId: 'listings' }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: 'status' },
                op: 'EQUAL',
                value: { stringValue: 'active' },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'visibility' },
                op: 'EQUAL',
                value: { stringValue: 'public' },
              },
            },
          ],
        },
      },
      orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
      limit: 10,
    },
  });

  const response = http.post(endpoint, payload, {
    headers: { 'Content-Type': 'application/json' },
    tags: { flow: 'browse_listings' },
  });
  listingsLatency.add(response.timings.duration);

  const ok = check(response, {
    'listings query returns 200': (res) => res.status === 200,
    'listings query returns JSON': (res) => {
      try {
        return Array.isArray(res.json());
      } catch (_) {
        return false;
      }
    },
  });
  errors.add(!ok);
}

export default function () {
  loadWebShell();
  browseLatestListings();
  sleep(Math.random() * 2 + 1);
}

export function handleSummary(data) {
  return {
    'load-tests/results/k6-summary.json': JSON.stringify(data, null, 2),
    stdout: JSON.stringify(
      {
        checks: data.metrics.checks,
        httpReqDuration: data.metrics.http_req_duration,
        errors: data.metrics.ilipresto_errors,
        listingsLatency: data.metrics.listings_latency,
      },
      null,
      2,
    ),
  };
}
