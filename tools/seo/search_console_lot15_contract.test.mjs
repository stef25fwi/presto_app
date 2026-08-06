import assert from 'node:assert/strict';
import fs from 'node:fs';

import {
  fetchSearchConsoleMetrics,
  resolveSearchConsoleSite,
  SearchConsoleAccessError,
} from './fetch_search_console_metrics.mjs';

const workflow = fs.readFileSync(
  '.github/workflows/search-console-lot15.yml',
  'utf8',
);
const reportBuilder = fs.readFileSync(
  'tools/seo/build_search_console_lot15_report.mjs',
  'utf8',
);

for (const token of [
  'quality/search-console-lot15',
  'webmasters.readonly',
  'search-console-lot15-report.json',
  'actions/upload-artifact@v7',
]) {
  assert.match(workflow, new RegExp(token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
}
assert.doesNotMatch(workflow, /gcloud services enable/);
assert.doesNotMatch(workflow, /analytics\.readonly|SEO_GA4_PROPERTY_ID/);
assert.match(reportBuilder, /zero-data-valid/);
assert.match(reportBuilder, /api_disabled/);
assert.match(reportBuilder, /serviceusage\.services\.enable/);

const selected = resolveSearchConsoleSite({
  accessibleSites: [
    { siteUrl: 'https://www.ilipresto.fr/', permissionLevel: 'siteFullUser' },
    { siteUrl: 'sc-domain:ilipresto.fr', permissionLevel: 'siteOwner' },
  ],
  preferredSiteUrl: 'sc-domain:ilipresto.fr',
  canonicalSiteUrl: 'https://ilipresto.fr',
});
assert.equal(selected.siteUrl, 'sc-domain:ilipresto.fr');
assert.equal(selected.permissionLevel, 'siteOwner');
assert.equal(selected.autoSelected, false);

const autoSelected = resolveSearchConsoleSite({
  accessibleSites: [
    { siteUrl: 'https://ilipresto.fr/', permissionLevel: 'siteFullUser' },
  ],
  preferredSiteUrl: 'sc-domain:ilipresto.fr',
  canonicalSiteUrl: 'https://ilipresto.fr',
});
assert.equal(autoSelected.siteUrl, 'https://ilipresto.fr/');
assert.equal(autoSelected.autoSelected, true);

assert.throws(
  () =>
    resolveSearchConsoleSite({
      accessibleSites: [{ siteUrl: 'sc-domain:example.com', permissionLevel: 'siteOwner' }],
      preferredSiteUrl: 'sc-domain:ilipresto.fr',
      canonicalSiteUrl: 'https://ilipresto.fr',
    }),
  (error) =>
    error instanceof SearchConsoleAccessError &&
    error.code === 'property_not_granted',
);

const config = {
  siteUrl: 'https://ilipresto.fr',
  searchConsoleSiteUrl: 'sc-domain:ilipresto.fr',
  dataLagDays: 3,
  currentPeriodDays: 28,
  comparisonPeriodDays: 28,
};
const originalFetch = globalThis.fetch;
const requests = [];
globalThis.fetch = async (url, options = {}) => {
  requests.push({ url: String(url), options });
  if (String(url).endsWith('/sites')) {
    return new Response(
      JSON.stringify({
        siteEntry: [
          { siteUrl: 'sc-domain:ilipresto.fr', permissionLevel: 'siteOwner' },
        ],
      }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  }
  const request = JSON.parse(String(options.body ?? '{}'));
  const keys = request.dimensions?.length ? ['example'] : undefined;
  return new Response(
    JSON.stringify({
      rows: [
        {
          ...(keys ? { keys } : {}),
          clicks: 4,
          impressions: 80,
          ctr: 0.05,
          position: 6.5,
        },
      ],
    }),
    { status: 200, headers: { 'content-type': 'application/json' } },
  );
};

try {
  const metrics = await fetchSearchConsoleMetrics({
    config,
    directAccessToken: 'short-lived-test-token',
    now: new Date('2026-08-05T12:00:00Z'),
  });
  assert.equal(metrics.status, 'available');
  assert.equal(metrics.siteUrl, 'sc-domain:ilipresto.fr');
  assert.equal(metrics.current.totals.impressions, 80);
  assert.equal(metrics.current.topQueries[0].query, 'example');
  assert.equal(requests.length, 9);
} finally {
  globalThis.fetch = originalFetch;
}

const apiDisabledFetch = globalThis.fetch;
globalThis.fetch = async () =>
  new Response(
    JSON.stringify({
      error: {
        message:
          'Google Search Console API has not been used in project 151421230024 before or it is disabled.',
      },
    }),
    { status: 403, headers: { 'content-type': 'application/json' } },
  );
try {
  await assert.rejects(
    fetchSearchConsoleMetrics({
      config,
      directAccessToken: 'short-lived-test-token',
    }),
    (error) =>
      error instanceof SearchConsoleAccessError && error.code === 'api_disabled',
  );
} finally {
  globalThis.fetch = apiDisabledFetch;
}

console.log('Search Console lot 15 contract: OK');
