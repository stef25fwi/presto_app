import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_SITE_URL = 'sc-domain:ilipresto.fr';
const DEFAULT_SITEMAPS = [
  'https://ilipresto.fr/sitemap.xml',
  'https://ilipresto.fr/sitemap-local.xml',
  'https://ilipresto.fr/sitemap-annonces.xml',
];

function argValue(prefix, fallback = '') {
  const value = process.argv.find((arg) => arg.startsWith(prefix));
  return value ? value.slice(prefix.length) : fallback;
}

function argValues(prefix) {
  return process.argv
    .filter((arg) => arg.startsWith(prefix))
    .map((arg) => arg.slice(prefix.length))
    .filter(Boolean);
}

function decodeXml(value) {
  return value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'");
}

export function parseSitemapXml(xml) {
  const urls = [];
  const matches = String(xml).matchAll(/<loc>\s*([^<]+?)\s*<\/loc>/giu);
  for (const match of matches) {
    const value = decodeXml(match[1].trim());
    if (value) urls.push(value);
  }
  return urls;
}

export function normalizeInspectableUrls(urls, canonicalHost = 'ilipresto.fr') {
  const normalized = new Set();
  for (const raw of urls) {
    try {
      const url = new URL(raw);
      if (url.protocol !== 'https:' || url.hostname !== canonicalHost) continue;
      url.hash = '';
      normalized.add(url.toString());
    } catch {
      // Une URL mal formée est ignorée ici puis visible via le nombre d'URLs sitemap.
    }
  }
  return [...normalized].sort();
}

export function classifyInspection(indexStatusResult = {}) {
  const verdict = indexStatusResult.verdict || 'VERDICT_UNSPECIFIED';
  const indexed = verdict === 'PASS';
  return {
    indexed,
    verdict,
    coverageState: indexStatusResult.coverageState || null,
    robotsTxtState: indexStatusResult.robotsTxtState || null,
    indexingState: indexStatusResult.indexingState || null,
    pageFetchState: indexStatusResult.pageFetchState || null,
    lastCrawlTime: indexStatusResult.lastCrawlTime || null,
    googleCanonical: indexStatusResult.googleCanonical || null,
    userCanonical: indexStatusResult.userCanonical || null,
  };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchText(url) {
  const response = await fetch(url, {
    headers: { 'user-agent': 'ilipresto-seo-indexation-certification/1.0' },
  });
  if (!response.ok) {
    throw new Error(`Sitemap ${url}: HTTP ${response.status}`);
  }
  return response.text();
}

async function inspectUrl({ inspectionUrl, siteUrl, accessToken }) {
  const response = await fetch(
    'https://searchconsole.googleapis.com/v1/urlInspection/index:inspect',
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        inspectionUrl,
        siteUrl,
        languageCode: 'fr-FR',
      }),
    },
  );

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = payload?.error?.message || `HTTP ${response.status}`;
    const error = new Error(`Inspection ${inspectionUrl}: ${message}`);
    error.status = response.status;
    throw error;
  }
  return payload;
}

function markdownReport(report) {
  const lines = [
    '# Certification d’indexation Google',
    '',
    `- Généré : ${report.generatedAt}`,
    `- Propriété : \`${report.siteUrl}\``,
    `- SHA : \`${report.sha || 'inconnu'}\``,
    `- URLs uniques des sitemaps : **${report.summary.discovered}**`,
    `- URLs inspectées : **${report.summary.inspected}**`,
    `- URLs indexées (verdict PASS) : **${report.summary.indexed}**`,
    `- URLs à examiner : **${report.summary.attention}**`,
    `- Erreurs d’inspection : **${report.summary.errors}**`,
    '',
    '## Sitemaps de production',
    '',
    ...report.sitemaps.map((item) => `- ${item.url} — ${item.urlCount} URL(s)`),
    '',
  ];

  const attention = report.urls.filter((item) => !item.indexed || item.error);
  if (attention.length === 0) {
    lines.push('## Résultat', '', 'Toutes les URLs inspectées ont un verdict Google `PASS`.', '');
  } else {
    lines.push('## URLs à examiner', '');
    lines.push('| URL | Verdict | Couverture | Crawl | Erreur |');
    lines.push('|---|---|---|---|---|');
    for (const item of attention) {
      lines.push(
        `| ${item.url} | ${item.verdict || '—'} | ${String(item.coverageState || '—').replaceAll('|', '\\|')} | ${item.lastCrawlTime || '—'} | ${String(item.error || '—').replaceAll('|', '\\|')} |`,
      );
    }
    lines.push('');
  }

  return `${lines.join('\n')}\n`;
}

async function main() {
  const accessToken = process.env.SEO_GOOGLE_ACCESS_TOKEN || '';
  if (!accessToken) throw new Error('SEO_GOOGLE_ACCESS_TOKEN manquant');

  const siteUrl = argValue('--site-url=', process.env.SEO_GSC_SITE_URL || DEFAULT_SITE_URL);
  const output = argValue('--output=', 'build/seo/search-console-indexation-report.json');
  const markdown = argValue('--markdown=', 'build/seo/search-console-indexation-report.md');
  const requestedSitemaps = argValues('--sitemap=');
  const sitemaps = requestedSitemaps.length ? requestedSitemaps : DEFAULT_SITEMAPS;
  const maxUrls = Math.max(1, Number(argValue('--max-urls=', process.env.SEO_INDEXATION_MAX_URLS || '500')) || 500);
  const delayMs = Math.max(0, Number(argValue('--delay-ms=', '125')) || 0);

  const sitemapResults = [];
  const sitemapUrls = [];
  for (const sitemapUrl of sitemaps) {
    const xml = await fetchText(sitemapUrl);
    const urls = parseSitemapXml(xml);
    sitemapResults.push({ url: sitemapUrl, urlCount: urls.length });
    sitemapUrls.push(...urls);
  }

  const urls = normalizeInspectableUrls(sitemapUrls).slice(0, maxUrls);
  const inspected = [];
  for (let index = 0; index < urls.length; index += 1) {
    const url = urls[index];
    try {
      const payload = await inspectUrl({ inspectionUrl: url, siteUrl, accessToken });
      const status = classifyInspection(payload?.inspectionResult?.indexStatusResult || {});
      inspected.push({ url, ...status, error: null });
    } catch (error) {
      inspected.push({
        url,
        indexed: false,
        verdict: null,
        coverageState: null,
        robotsTxtState: null,
        indexingState: null,
        pageFetchState: null,
        lastCrawlTime: null,
        googleCanonical: null,
        userCanonical: null,
        error: error.message,
      });
    }
    if (delayMs && index < urls.length - 1) await sleep(delayMs);
  }

  const errors = inspected.filter((item) => item.error).length;
  const indexed = inspected.filter((item) => item.indexed).length;
  const attention = inspected.length - indexed;
  const report = {
    version: 1,
    generatedAt: new Date().toISOString(),
    sha: process.env.GITHUB_SHA || null,
    siteUrl,
    status: errors === 0 ? 'available' : 'partial',
    certification: errors === 0 && attention === 0 ? 'verified' : 'attention',
    sitemaps: sitemapResults,
    summary: {
      discovered: normalizeInspectableUrls(sitemapUrls).length,
      inspected: inspected.length,
      indexed,
      attention,
      errors,
      truncated: normalizeInspectableUrls(sitemapUrls).length > urls.length,
    },
    urls: inspected,
  };

  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.mkdirSync(path.dirname(markdown), { recursive: true });
  fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
  fs.writeFileSync(markdown, markdownReport(report));

  console.log(
    `Search Console indexation: ${indexed}/${inspected.length} indexées, ${errors} erreur(s), ${report.summary.discovered} URL(s) découvertes.`,
  );
  if (errors > 0) process.exitCode = 1;
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(currentFile)) {
  main().catch((error) => {
    console.error(error.stack || error.message || error);
    process.exit(1);
  });
}
