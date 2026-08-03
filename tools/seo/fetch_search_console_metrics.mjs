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

const SEARCH_CONSOLE_SCOPE =
  'https://www.googleapis.com/auth/webmasters.readonly';

async function querySearchConsole(accessToken, siteUrl, request) {
  const endpoint = `https://www.googleapis.com/webmasters/v3/sites/${encodeURIComponent(
    siteUrl,
  )}/searchAnalytics/query`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(request),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message =
      payload?.error?.message ?? payload?.error_description ?? response.statusText;
    throw new Error(`Search Console API failed (${response.status}): ${message}`);
  }
  return payload;
}

function normalizeTotals(payload) {
  const row = payload?.rows?.[0] ?? {};
  return {
    clicks: round(row.clicks),
    impressions: round(row.impressions),
    ctrPercent: round(Number(row.ctr ?? 0) * 100),
    averagePosition: round(row.position),
  };
}

function normalizeDimensionRows(payload, dimensionName) {
  return (payload?.rows ?? []).map((row) => ({
    [dimensionName]: String(row.keys?.[0] ?? ''),
    clicks: round(row.clicks),
    impressions: round(row.impressions),
    ctrPercent: round(Number(row.ctr ?? 0) * 100),
    averagePosition: round(row.position),
  }));
}

async function fetchPeriod(accessToken, siteUrl, period) {
  const baseRequest = {
    startDate: period.startDate,
    endDate: period.endDate,
    type: 'web',
    dataState: 'final',
  };
  const [totals, queries, pages, devices] = await Promise.all([
    querySearchConsole(accessToken, siteUrl, {
      ...baseRequest,
      aggregationType: 'auto',
      rowLimit: 1,
    }),
    querySearchConsole(accessToken, siteUrl, {
      ...baseRequest,
      dimensions: ['query'],
      rowLimit: 25,
    }),
    querySearchConsole(accessToken, siteUrl, {
      ...baseRequest,
      dimensions: ['page'],
      rowLimit: 25,
    }),
    querySearchConsole(accessToken, siteUrl, {
      ...baseRequest,
      dimensions: ['device'],
      rowLimit: 10,
    }),
  ]);
  return {
    period,
    totals: normalizeTotals(totals),
    topQueries: normalizeDimensionRows(queries, 'query'),
    topPages: normalizeDimensionRows(pages, 'page'),
    devices: normalizeDimensionRows(devices, 'device'),
  };
}

export async function fetchSearchConsoleMetrics({
  config,
  directAccessToken = '',
  serviceAccountJson = '',
  siteUrl = config.searchConsoleSiteUrl,
  now = new Date(),
}) {
  const accessToken = await getGoogleAccessToken({
    directAccessToken,
    serviceAccountJson,
    scopes: [SEARCH_CONSOLE_SCOPE],
  });
  const periods = buildComparisonPeriods(config, now);
  const [current, previous] = await Promise.all([
    fetchPeriod(accessToken, siteUrl, periods.current),
    fetchPeriod(accessToken, siteUrl, periods.previous),
  ]);
  return {
    status: 'available',
    siteUrl,
    current,
    previous,
    changes: {
      clicksPercent: round(
        percentageChange(current.totals.clicks, previous.totals.clicks) ?? 0,
      ),
      impressionsPercent: round(
        percentageChange(
          current.totals.impressions,
          previous.totals.impressions,
        ) ?? 0,
      ),
      ctrPercentagePoints: round(
        current.totals.ctrPercent - previous.totals.ctrPercent,
      ),
      averagePositionDelta: round(
        current.totals.averagePosition - previous.totals.averagePosition,
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
    const result = await fetchSearchConsoleMetrics({
      config,
      directAccessToken: process.env.SEO_GOOGLE_ACCESS_TOKEN ?? '',
      serviceAccountJson:
        process.env.SEO_GOOGLE_SERVICE_ACCOUNT_JSON ??
        process.env.GOOGLE_SERVICE_ACCOUNT_JSON ??
        '',
      siteUrl: process.env.SEO_GSC_SITE_URL ?? config.searchConsoleSiteUrl,
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
