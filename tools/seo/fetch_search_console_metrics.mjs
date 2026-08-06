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
const SEARCH_CONSOLE_API_ROOT = 'https://www.googleapis.com/webmasters/v3';

export class SearchConsoleAccessError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'SearchConsoleAccessError';
    this.code = code;
    this.details = details;
  }
}

function normalizeSiteUrl(value) {
  const raw = String(value ?? '').trim();
  if (!raw) return '';
  if (raw.startsWith('sc-domain:')) {
    return `sc-domain:${raw.slice('sc-domain:'.length).toLowerCase()}`;
  }
  try {
    const url = new URL(raw);
    url.hash = '';
    url.search = '';
    if (!url.pathname.endsWith('/')) url.pathname += '/';
    return url.toString();
  } catch {
    return raw;
  }
}

function classifyApiFailure(status, payload, fallbackMessage) {
  const message = String(
    payload?.error?.message ?? payload?.error_description ?? fallbackMessage ?? '',
  );
  const lowered = message.toLowerCase();
  if (
    status === 403 &&
    (lowered.includes('has not been used') ||
      lowered.includes('is disabled') ||
      lowered.includes('access not configured'))
  ) {
    return new SearchConsoleAccessError(
      'api_disabled',
      'Google Search Console API is disabled for the Google Cloud project used by GitHub Actions.',
      { status, upstreamMessage: message },
    );
  }
  if (status === 401) {
    return new SearchConsoleAccessError(
      'authentication_failed',
      'Google authentication failed or the short-lived token expired.',
      { status, upstreamMessage: message },
    );
  }
  if (status === 403) {
    return new SearchConsoleAccessError(
      'permission_denied',
      'The federated Google service account cannot access the requested Search Console resource.',
      { status, upstreamMessage: message },
    );
  }
  if (status === 404) {
    return new SearchConsoleAccessError(
      'property_not_found',
      'The requested Search Console property was not found.',
      { status, upstreamMessage: message },
    );
  }
  return new SearchConsoleAccessError(
    'api_error',
    `Search Console API failed (${status}): ${message}`,
    { status, upstreamMessage: message },
  );
}

async function searchConsoleRequest(accessToken, path, options = {}) {
  const response = await fetch(`${SEARCH_CONSOLE_API_ROOT}${path}`, {
    ...options,
    headers: {
      authorization: `Bearer ${accessToken}`,
      ...(options.body ? { 'content-type': 'application/json' } : {}),
      ...(options.headers ?? {}),
    },
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw classifyApiFailure(response.status, payload, response.statusText);
  }
  return payload;
}

export async function listSearchConsoleSites(accessToken) {
  const payload = await searchConsoleRequest(accessToken, '/sites');
  return (payload?.siteEntry ?? [])
    .map((entry) => ({
      siteUrl: normalizeSiteUrl(entry?.siteUrl),
      permissionLevel: String(entry?.permissionLevel ?? 'unknown'),
    }))
    .filter((entry) => entry.siteUrl);
}

function candidateScore(siteUrl, preferredSiteUrl, canonicalSiteUrl) {
  const normalized = normalizeSiteUrl(siteUrl);
  const preferred = normalizeSiteUrl(preferredSiteUrl);
  if (normalized === preferred) return 1000;

  let canonicalHost = '';
  try {
    canonicalHost = new URL(canonicalSiteUrl).hostname.toLowerCase();
  } catch {
    canonicalHost = String(canonicalSiteUrl ?? '')
      .replace(/^https?:\/\//u, '')
      .replace(/\/$/u, '')
      .toLowerCase();
  }
  const rootHost = canonicalHost.replace(/^www\./u, '');
  if (normalized === `sc-domain:${rootHost}`) return 900;
  if (normalized === `https://${rootHost}/`) return 800;
  if (normalized === `https://www.${rootHost}/`) return 750;
  if (normalized.includes(rootHost)) return 500;
  return 0;
}

export function resolveSearchConsoleSite({
  accessibleSites,
  preferredSiteUrl,
  canonicalSiteUrl,
}) {
  const ranked = accessibleSites
    .map((site) => ({
      ...site,
      score: candidateScore(site.siteUrl, preferredSiteUrl, canonicalSiteUrl),
    }))
    .sort((left, right) => right.score - left.score);
  const selected = ranked[0];
  if (!selected || selected.score <= 0) {
    throw new SearchConsoleAccessError(
      'property_not_granted',
      'The federated Google service account has no ilipresto.fr property in Search Console.',
      {
        requestedSiteUrl: normalizeSiteUrl(preferredSiteUrl),
        accessibleSites: accessibleSites.map((site) => site.siteUrl),
      },
    );
  }
  return {
    siteUrl: selected.siteUrl,
    permissionLevel: selected.permissionLevel,
    autoSelected:
      normalizeSiteUrl(selected.siteUrl) !== normalizeSiteUrl(preferredSiteUrl),
  };
}

async function querySearchConsole(accessToken, siteUrl, request) {
  return searchConsoleRequest(
    accessToken,
    `/sites/${encodeURIComponent(siteUrl)}/searchAnalytics/query`,
    {
      method: 'POST',
      body: JSON.stringify(request),
    },
  );
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
  const accessibleSites = await listSearchConsoleSites(accessToken);
  const selectedSite = resolveSearchConsoleSite({
    accessibleSites,
    preferredSiteUrl: siteUrl,
    canonicalSiteUrl: config.siteUrl,
  });
  const periods = buildComparisonPeriods(config, now);
  const [current, previous] = await Promise.all([
    fetchPeriod(accessToken, selectedSite.siteUrl, periods.current),
    fetchPeriod(accessToken, selectedSite.siteUrl, periods.previous),
  ]);
  return {
    status: 'available',
    siteUrl: selectedSite.siteUrl,
    permissionLevel: selectedSite.permissionLevel,
    autoSelectedProperty: selectedSite.autoSelected,
    accessibleSites,
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
