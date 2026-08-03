import { pathToFileURL } from 'node:url';

import { getGoogleAccessToken } from './google_service_account_auth.mjs';
import {
  buildComparisonPeriods,
  loadSeoMonitoringConfig,
  percentageChange,
  round,
  safeErrorMessage,
  writeJsonFile,
} from './seo_monitoring_utils.mjs';

const ANALYTICS_SCOPE = 'https://www.googleapis.com/auth/analytics.readonly';

async function runReport(accessToken, propertyId, request) {
  const response = await fetch(
    `https://analyticsdata.googleapis.com/v1beta/properties/${encodeURIComponent(
      propertyId,
    )}:runReport`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(request),
    },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = payload?.error?.message ?? response.statusText;
    throw new Error(`GA4 Data API failed (${response.status}): ${message}`);
  }
  return payload;
}

function organicFilter() {
  return {
    filter: {
      fieldName: 'sessionDefaultChannelGroup',
      stringFilter: {
        matchType: 'EXACT',
        value: 'Organic Search',
        caseSensitive: false,
      },
    },
  };
}

function rowsToObjects(payload) {
  const dimensionNames = (payload.dimensionHeaders ?? []).map(
    (header) => header.name,
  );
  const metricNames = (payload.metricHeaders ?? []).map((header) => header.name);
  return (payload.rows ?? []).map((row) => {
    const value = {};
    dimensionNames.forEach((name, index) => {
      value[name] = String(row.dimensionValues?.[index]?.value ?? '');
    });
    metricNames.forEach((name, index) => {
      value[name] = round(row.metricValues?.[index]?.value);
    });
    return value;
  });
}

async function fetchPeriod(
  accessToken,
  propertyId,
  period,
  conversionEvents,
  keyEventMetric,
) {
  const dateRanges = [{ startDate: period.startDate, endDate: period.endDate }];
  const metrics = [
    { name: 'sessions' },
    { name: 'engagedSessions' },
    { name: keyEventMetric },
  ];
  const [totalsPayload, landingPagesPayload, eventsPayload] = await Promise.all([
    runReport(accessToken, propertyId, {
      dateRanges,
      metrics,
      dimensionFilter: organicFilter(),
      keepEmptyRows: true,
    }),
    runReport(accessToken, propertyId, {
      dateRanges,
      dimensions: [{ name: 'landingPagePlusQueryString' }],
      metrics,
      dimensionFilter: organicFilter(),
      orderBys: [{ metric: { metricName: 'sessions' }, desc: true }],
      limit: '25',
    }),
    runReport(accessToken, propertyId, {
      dateRanges,
      dimensions: [{ name: 'eventName' }],
      metrics: [{ name: 'eventCount' }],
      dimensionFilter: {
        andGroup: {
          expressions: [
            organicFilter(),
            {
              filter: {
                fieldName: 'eventName',
                inListFilter: {
                  values: conversionEvents,
                  caseSensitive: true,
                },
              },
            },
          ],
        },
      },
      orderBys: [{ metric: { metricName: 'eventCount' }, desc: true }],
      limit: String(Math.max(conversionEvents.length, 10)),
    }),
  ]);

  const totalsRow = rowsToObjects(totalsPayload)[0] ?? {};
  return {
    period,
    totals: {
      sessions: round(totalsRow.sessions),
      engagedSessions: round(totalsRow.engagedSessions),
      organicKeyEvents: round(totalsRow[keyEventMetric]),
      engagementRatePercent:
        Number(totalsRow.sessions) > 0
          ? round(
              (Number(totalsRow.engagedSessions) / Number(totalsRow.sessions)) *
                100,
            )
          : 0,
    },
    topLandingPages: rowsToObjects(landingPagesPayload),
    conversionEvents: rowsToObjects(eventsPayload),
  };
}

export async function fetchGa4Metrics({
  config,
  serviceAccountJson,
  propertyId,
  now = new Date(),
}) {
  if (!String(propertyId ?? '').trim()) {
    throw new Error('SEO_GA4_PROPERTY_ID is missing.');
  }
  const accessToken = await getGoogleAccessToken({
    serviceAccountJson,
    scopes: [ANALYTICS_SCOPE],
  });
  const periods = buildComparisonPeriods(config, now);

  let keyEventMetric = 'keyEvents';
  let current;
  let previous;
  try {
    [current, previous] = await Promise.all([
      fetchPeriod(
        accessToken,
        propertyId,
        periods.current,
        config.conversionEvents,
        keyEventMetric,
      ),
      fetchPeriod(
        accessToken,
        propertyId,
        periods.previous,
        config.conversionEvents,
        keyEventMetric,
      ),
    ]);
  } catch (error) {
    if (!String(error).includes('keyEvents')) throw error;
    keyEventMetric = 'conversions';
    [current, previous] = await Promise.all([
      fetchPeriod(
        accessToken,
        propertyId,
        periods.current,
        config.conversionEvents,
        keyEventMetric,
      ),
      fetchPeriod(
        accessToken,
        propertyId,
        periods.previous,
        config.conversionEvents,
        keyEventMetric,
      ),
    ]);
  }

  return {
    status: 'available',
    propertyId: String(propertyId),
    measurementId: config.ga4MeasurementId,
    keyEventMetric,
    current,
    previous,
    changes: {
      sessionsPercent: round(
        percentageChange(
          current.totals.sessions,
          previous.totals.sessions,
        ) ?? 0,
      ),
      engagedSessionsPercent: round(
        percentageChange(
          current.totals.engagedSessions,
          previous.totals.engagedSessions,
        ) ?? 0,
      ),
      organicKeyEventsPercent: round(
        percentageChange(
          current.totals.organicKeyEvents,
          previous.totals.organicKeyEvents,
        ) ?? 0,
      ),
      engagementRatePercentagePoints: round(
        current.totals.engagementRatePercent -
          previous.totals.engagementRatePercent,
      ),
    },
  };
}

async function runCli() {
  const config = await loadSeoMonitoringConfig();
  const outputIndex = process.argv.indexOf('--output');
  const outputPath =
    outputIndex >= 0 ? process.argv[outputIndex + 1] : undefined;
  try {
    const result = await fetchGa4Metrics({
      config,
      serviceAccountJson:
        process.env.SEO_GOOGLE_SERVICE_ACCOUNT_JSON ??
        process.env.GOOGLE_SERVICE_ACCOUNT_JSON ??
        '',
      propertyId: process.env.SEO_GA4_PROPERTY_ID ?? '',
    });
    if (outputPath) await writeJsonFile(outputPath, result);
    else console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(safeErrorMessage(error));
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await runCli();
}
