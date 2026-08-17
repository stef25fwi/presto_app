import assert from 'node:assert/strict';
import {
  classifyInspection,
  normalizeInspectableUrls,
  parseSitemapXml,
} from './build_search_console_indexation_report.mjs';

const xml = `<?xml version="1.0"?><urlset>
  <url><loc>https://ilipresto.fr/</loc></url>
  <url><loc>https://ilipresto.fr/services?x=1&amp;y=2</loc></url>
</urlset>`;

assert.deepEqual(parseSitemapXml(xml), [
  'https://ilipresto.fr/',
  'https://ilipresto.fr/services?x=1&y=2',
]);

assert.deepEqual(
  normalizeInspectableUrls([
    'https://ilipresto.fr/a#fragment',
    'https://ilipresto.fr/a',
    'http://ilipresto.fr/insecure',
    'https://example.com/externe',
  ]),
  ['https://ilipresto.fr/a'],
);

assert.deepEqual(
  classifyInspection({
    verdict: 'PASS',
    coverageState: 'Submitted and indexed',
    robotsTxtState: 'ALLOWED',
    indexingState: 'INDEXING_ALLOWED',
    pageFetchState: 'SUCCESSFUL',
    lastCrawlTime: '2026-08-17T00:00:00Z',
    googleCanonical: 'https://ilipresto.fr/a',
    userCanonical: 'https://ilipresto.fr/a',
  }),
  {
    indexed: true,
    verdict: 'PASS',
    coverageState: 'Submitted and indexed',
    robotsTxtState: 'ALLOWED',
    indexingState: 'INDEXING_ALLOWED',
    pageFetchState: 'SUCCESSFUL',
    lastCrawlTime: '2026-08-17T00:00:00Z',
    googleCanonical: 'https://ilipresto.fr/a',
    userCanonical: 'https://ilipresto.fr/a',
  },
);

assert.equal(classifyInspection({ verdict: 'NEUTRAL' }).indexed, false);
console.log('Search Console indexation report: parsing et classification validés.');
