import { pathToFileURL } from 'node:url';

import { validateRuntimeSeoRegistry } from './runtime_seo_registry_contract.mjs';
import {
  loadSeoMonitoringConfig,
  round,
  safeErrorMessage,
  writeJsonFile,
} from './seo_monitoring_utils.mjs';

const HTML_ENTITIES = Object.freeze({
  '&amp;': '&',
  '&quot;': '"',
  '&#39;': "'",
  '&lt;': '<',
  '&gt;': '>',
});

function decodeHtml(value) {
  return String(value ?? '')
    .replace(/&(amp|quot|#39|lt|gt);/gu, (entity) => HTML_ENTITIES[entity] ?? entity)
    .replace(/\s+/gu, ' ')
    .trim();
}

function extractFirst(html, pattern) {
  const match = pattern.exec(html);
  return decodeHtml(match?.[1] ?? '');
}

function extractMeta(html, key, value) {
  const escaped = value.replace(/[.*+?^${}()|[\]\\]/gu, '\\$&');
  const patterns = [
    new RegExp(
      `<meta[^>]+${key}=["']${escaped}["'][^>]+content=["']([^"']*)["'][^>]*>`,
      'iu',
    ),
    new RegExp(
      `<meta[^>]+content=["']([^"']*)["'][^>]+${key}=["']${escaped}["'][^>]*>`,
      'iu',
    ),
  ];
  for (const pattern of patterns) {
    const valueFound = extractFirst(html, pattern);
    if (valueFound) return valueFound;
  }
  return '';
}

function extractCanonical(html) {
  const patterns = [
    /<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["'][^>]*>/iu,
    /<link[^>]+href=["']([^"']+)["'][^>]+rel=["']canonical["'][^>]*>/iu,
  ];
  for (const pattern of patterns) {
    const value = extractFirst(html, pattern);
    if (value) return value;
  }
  return '';
}

function stripTags(value) {
  return decodeHtml(String(value ?? '').replace(/<[^>]+>/gu, ' '));
}

function normalizedUrl(value) {
  const url = new URL(value);
  url.hash = '';
  if (url.pathname !== '/') url.pathname = url.pathname.replace(/\/+$/u, '');
  return url.toString();
}

async function fetchText(url, timeoutMs = 15000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const startedAt = performance.now();
  try {
    const response = await fetch(url, {
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'user-agent': 'ilipresto-seo-monitor/1.0 (+https://ilipresto.fr)',
      },
    });
    return {
      status: response.status,
      ok: response.ok,
      finalUrl: response.url,
      contentType: response.headers.get('content-type') ?? '',
      responseTimeMs: round(performance.now() - startedAt),
      text: await response.text(),
    };
  } finally {
    clearTimeout(timeout);
  }
}

function validateHtmlPage({ html, expectedUrl, config }) {
  const thresholds = config.thresholds;
  const title = extractFirst(html, /<title[^>]*>([\s\S]*?)<\/title>/iu);
  const description = extractMeta(html, 'name', 'description');
  const robots = extractMeta(html, 'name', 'robots').toLowerCase();
  const canonical = extractCanonical(html);
  const h1 = [...html.matchAll(/<h1\b[^>]*>([\s\S]*?)<\/h1>/giu)]
    .map((match) => stripTags(match[1]))
    .filter(Boolean);
  const jsonLdCount = (html.match(/type=["']application\/ld\+json["']/giu) ?? [])
    .length;
  const errors = [];
  const warnings = [];

  if (!title) errors.push('title_missing');
  else if (
    title.length < thresholds.titleLengthMin ||
    title.length > thresholds.titleLengthMax
  ) {
    warnings.push(`title_length_${title.length}`);
  }
  if (!description) errors.push('description_missing');
  else if (
    description.length < thresholds.descriptionLengthMin ||
    description.length > thresholds.descriptionLengthMax
  ) {
    warnings.push(`description_length_${description.length}`);
  }
  if (!canonical) errors.push('canonical_missing');
  else if (normalizedUrl(canonical) !== normalizedUrl(expectedUrl)) {
    errors.push(`canonical_mismatch:${canonical}`);
  }
  if (h1.length !== 1) errors.push(`h1_count_${h1.length}`);
  if (robots.includes('noindex')) errors.push('robots_noindex');
  if (jsonLdCount < 1) errors.push('structured_data_missing');

  return {
    title,
    description,
    canonical,
    h1,
    robots,
    jsonLdCount,
    errors,
    warnings,
  };
}

export async function monitorPublicSeo({ config }) {
  const siteUrl = config.siteUrl.replace(/\/+$/u, '');
  const registryUrl = `${siteUrl}/public-route-seo.js`;
  const [registryResponse, robotsResponse, sitemapResponse] = await Promise.all([
    fetchText(registryUrl),
    fetchText(`${siteUrl}/robots.txt`),
    fetchText(`${siteUrl}/sitemap.xml`),
  ]);
  const pages = [];

  for (const page of config.monitoredPages) {
    const expectedUrl = `${siteUrl}${page.path === '/' ? '/' : page.path}`;
    try {
      const response = await fetchText(expectedUrl);
      const errors = [];
      const warnings = [];
      if (!response.ok) errors.push(`http_${response.status}`);
      if (!response.contentType.toLowerCase().includes('text/html')) {
        errors.push(`content_type:${response.contentType}`);
      }
      if (new URL(response.finalUrl).hostname !== new URL(siteUrl).hostname) {
        errors.push(`unexpected_host:${response.finalUrl}`);
      }
      if (response.responseTimeMs > config.thresholds.maxResponseTimeMs) {
        warnings.push(`slow_response_${response.responseTimeMs}ms`);
      }

      let metadata;
      if (page.validationMode === 'runtime-registry') {
        if (!registryResponse.ok) errors.push('runtime_registry_unavailable');
        const contract = validateRuntimeSeoRegistry({
          registrySource: registryResponse.text,
          routePath: page.path,
          siteUrl,
        });
        errors.push(...contract.errors);
        metadata = {
          mode: 'runtime-registry',
          registryUrl,
          ...contract,
        };
      } else {
        metadata = validateHtmlPage({
          html: response.text,
          expectedUrl,
          config,
        });
        errors.push(...metadata.errors);
        warnings.push(...metadata.warnings);
      }

      pages.push({
        path: page.path,
        priority: page.priority,
        validationMode: page.validationMode,
        expectedUrl,
        finalUrl: response.finalUrl,
        statusCode: response.status,
        responseTimeMs: response.responseTimeMs,
        contentType: response.contentType,
        metadata,
        errors,
        warnings,
        healthy: errors.length === 0,
      });
    } catch (error) {
      pages.push({
        path: page.path,
        priority: page.priority,
        validationMode: page.validationMode,
        expectedUrl,
        errors: [`request_failed:${safeErrorMessage(error)}`],
        warnings: [],
        healthy: false,
      });
    }
  }

  const infrastructureErrors = [];
  const infrastructureWarnings = [];
  if (!robotsResponse.ok) infrastructureErrors.push('robots_unavailable');
  if (!sitemapResponse.ok) infrastructureErrors.push('sitemap_unavailable');
  if (!registryResponse.ok) infrastructureErrors.push('route_registry_unavailable');
  if (!robotsResponse.text.includes(`Sitemap: ${siteUrl}/sitemap.xml`)) {
    infrastructureErrors.push('robots_sitemap_reference_missing');
  }
  if (/Disallow:\s*\/\s*$/imu.test(robotsResponse.text)) {
    infrastructureErrors.push('robots_blocks_site');
  }
  for (const page of config.monitoredPages) {
    const url = `${siteUrl}${page.path === '/' ? '/' : page.path}`;
    if (!sitemapResponse.text.includes(`<loc>${url}</loc>`)) {
      infrastructureErrors.push(`sitemap_missing:${page.path}`);
    }
  }
  if (robotsResponse.responseTimeMs > config.thresholds.maxResponseTimeMs) {
    infrastructureWarnings.push('robots_slow');
  }
  if (sitemapResponse.responseTimeMs > config.thresholds.maxResponseTimeMs) {
    infrastructureWarnings.push('sitemap_slow');
  }

  const healthyPages = pages.filter((page) => page.healthy).length;
  const availabilityPercent = round((healthyPages / pages.length) * 100);
  const errors = [
    ...infrastructureErrors,
    ...pages.flatMap((page) =>
      page.errors.map((error) => `${page.path}:${error}`),
    ),
  ];
  const warnings = [
    ...infrastructureWarnings,
    ...pages.flatMap((page) =>
      page.warnings.map((warning) => `${page.path}:${warning}`),
    ),
  ];
  if (availabilityPercent < config.thresholds.availabilityPercentMin) {
    errors.push(`availability_${availabilityPercent}`);
  }

  return {
    status: errors.length === 0 ? (warnings.length ? 'warning' : 'healthy') : 'critical',
    checkedAt: new Date().toISOString(),
    siteUrl,
    availabilityPercent,
    healthyPages,
    totalPages: pages.length,
    infrastructure: {
      robots: {
        statusCode: robotsResponse.status,
        responseTimeMs: robotsResponse.responseTimeMs,
      },
      sitemap: {
        statusCode: sitemapResponse.status,
        responseTimeMs: sitemapResponse.responseTimeMs,
      },
      runtimeRegistry: {
        statusCode: registryResponse.status,
        responseTimeMs: registryResponse.responseTimeMs,
      },
      errors: infrastructureErrors,
      warnings: infrastructureWarnings,
    },
    pages,
    errors,
    warnings,
  };
}

async function runCli() {
  const config = await loadSeoMonitoringConfig();
  const enforce = process.argv.includes('--enforce');
  const outputIndex = process.argv.indexOf('--output');
  const outputPath =
    outputIndex >= 0
      ? process.argv[outputIndex + 1]
      : 'build/seo/public-seo-health.json';
  try {
    const report = await monitorPublicSeo({ config });
    await writeJsonFile(outputPath, report);
    console.log(
      `SEO production health: ${report.status} (${report.healthyPages}/${report.totalPages} pages)`,
    );
    if (report.errors.length) {
      for (const error of report.errors) console.error(`- ${error}`);
    }
    if (enforce && report.status === 'critical') process.exitCode = 1;
  } catch (error) {
    console.error(safeErrorMessage(error));
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await runCli();
}
