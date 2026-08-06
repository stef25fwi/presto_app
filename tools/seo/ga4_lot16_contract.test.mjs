import assert from 'node:assert/strict';
import fs from 'node:fs';

import {
  buildGa4Lot16Report,
  classifyGa4Error,
  markdownFor,
  remediationFor,
} from './build_ga4_lot16_report.mjs';

const config = {
  ga4MeasurementId: 'G-NT4PEHQ3CJ',
  conversionEvents: ['registration_completed'],
};

function metrics(overrides = {}) {
  const base = {
    status: 'available',
    propertyId: '123456789',
    measurementId: 'G-NT4PEHQ3CJ',
    keyEventMetric: 'keyEvents',
    current: {
      period: { startDate: '2026-07-07', endDate: '2026-08-03' },
      totals: {
        sessions: 12,
        engagedSessions: 9,
        organicKeyEvents: 2,
        engagementRatePercent: 75,
      },
      topLandingPages: [
        {
          landingPagePlusQueryString: '/',
          sessions: 12,
          engagedSessions: 9,
          keyEvents: 2,
        },
      ],
      conversionEvents: [
        { eventName: 'registration_completed', eventCount: 2 },
      ],
    },
    previous: {
      period: { startDate: '2026-06-09', endDate: '2026-07-06' },
      totals: {
        sessions: 8,
        engagedSessions: 5,
        organicKeyEvents: 1,
        engagementRatePercent: 62.5,
      },
      topLandingPages: [],
      conversionEvents: [],
    },
    changes: {
      sessionsPercent: 50,
      engagedSessionsPercent: 80,
      organicKeyEventsPercent: 100,
      engagementRatePercentagePoints: 12.5,
    },
  };
  return { ...base, ...overrides };
}

const available = await buildGa4Lot16Report({
  config,
  fetchMetrics: async () => metrics(),
  now: new Date('2026-08-06T09:00:00.000Z'),
});
assert.equal(available.report.status, 'available');
assert.equal(available.report.dataStatus, 'data-present');
assert.equal(available.report.statusContext, 'quality/ga4-organic-lot16');
assert.equal(available.report.propertyId, '123456789');
assert.equal(available.workflowState, 'success');
assert.match(markdownFor(available.report), /12 \| 9 \| 75 % \| 2/u);

const zero = await buildGa4Lot16Report({
  config,
  fetchMetrics: async () => {
    const value = metrics();
    value.current.totals = {
      sessions: 0,
      engagedSessions: 0,
      organicKeyEvents: 0,
      engagementRatePercent: 0,
    };
    value.current.topLandingPages = [];
    value.current.conversionEvents = [];
    return value;
  },
});
assert.equal(zero.report.status, 'available');
assert.equal(zero.report.dataStatus, 'zero-data-valid');
assert.equal(zero.workflowState, 'success');

assert.equal(
  classifyGa4Error(
    new Error('Analytics Data API has not been used in project or it is disabled'),
  ),
  'api_disabled',
);
assert.equal(
  classifyGa4Error(
    new Error('No GA4 property visible to this identity contains measurement ID'),
  ),
  'property_not_granted',
);
assert.equal(
  classifyGa4Error(new Error('Google Analytics API failed (401): UNAUTHENTICATED')),
  'authentication_failed',
);
assert.match(remediationFor('api_disabled'), /analyticsdata.googleapis.com/u);
assert.match(remediationFor('property_not_granted'), /github-firebase-deploy/u);

const workflow = fs.readFileSync(
  '.github/workflows/ga4-organic-lot16.yml',
  'utf8',
);
assert.match(workflow, /google-github-actions\/auth@v3/u);
assert.match(workflow, /analytics\.readonly/u);
assert.match(workflow, /quality\/ga4-organic-lot16/u);
assert.match(workflow, /retention-days: 90/u);
assert.match(workflow, /\[SEO lot 16\] GA4 Organic Search/u);
assert.match(workflow, /Enforce GA4 availability/u);

const registry = JSON.parse(
  fs.readFileSync('quality/seo_acquisition_readiness.json', 'utf8'),
);
const control = registry.controls.find(
  (item) => item.id === 'ga4_organic_search',
);
assert.ok(control, 'ga4_organic_search control must exist');
assert.equal(control.status, 'pending');
assert.match(control.evidence, /quality\/ga4-organic-lot16/u);

console.log('GA4 Organic Search lot 16 contract: OK');
