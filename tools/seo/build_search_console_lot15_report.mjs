#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';

import {
  fetchSearchConsoleMetrics,
  SearchConsoleAccessError,
} from './fetch_search_console_metrics.mjs';
import {
  loadSeoMonitoringConfig,
  safeErrorMessage,
  writeJsonFile,
} from './seo_monitoring_utils.mjs';

function argumentValue(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

function markdownFor(report) {
  const lines = [
    '# Search Console automatisée — lot 15',
    '',
    `- Statut : **${report.status}**`,
    `- Généré le : **${report.generatedAt}**`,
    `- Propriété demandée : **${report.requestedSiteUrl}**`,
  ];

  if (report.status === 'available') {
    lines.push(
      `- Propriété utilisée : **${report.siteUrl}**`,
      `- Permission : **${report.permissionLevel}**`,
      `- Données : **${report.dataStatus}**`,
      '',
      '| Période | Clics | Impressions | CTR | Position moyenne |',
      '|---|---:|---:|---:|---:|',
      `| Actuelle | ${report.current.totals.clicks} | ${report.current.totals.impressions} | ${report.current.totals.ctrPercent} % | ${report.current.totals.averagePosition} |`,
      `| Précédente | ${report.previous.totals.clicks} | ${report.previous.totals.impressions} | ${report.previous.totals.ctrPercent} % | ${report.previous.totals.averagePosition} |`,
      '',
      `Propriétés accessibles : ${report.accessibleSites
        .map((site) => `${site.siteUrl} (${site.permissionLevel})`)
        .join(', ') || 'aucune'}.`,
    );
  } else {
    lines.push(
      `- Code de blocage : **${report.errorCode}**`,
      '',
      `> ${report.errorMessage}`,
      '',
      '## Action requise',
      '',
      report.remediation,
    );
  }
  lines.push('');
  return lines.join('\n');
}

function remediationFor(code) {
  switch (code) {
    case 'api_disabled':
      return 'Activer `searchconsole.googleapis.com` dans le projet Google Cloud `151421230024`, puis relancer le workflow. Cette opération doit être faite une seule fois par un compte disposant de `serviceusage.services.enable`.';
    case 'property_not_granted':
    case 'permission_denied':
      return 'Ajouter le compte de service fédéré utilisé par `WIF_SERVICE_ACCOUNT` comme utilisateur de la propriété `sc-domain:ilipresto.fr` dans Search Console, avec au minimum un accès complet.';
    case 'authentication_failed':
      return 'Vérifier la configuration `WIF_PROVIDER` et `WIF_SERVICE_ACCOUNT` de l’environnement GitHub `recaptcha`.';
    default:
      return 'Consulter le message amont dans l’artefact, corriger l’accès Google, puis relancer le workflow.';
  }
}

const config = await loadSeoMonitoringConfig();
const outputPath = argumentValue(
  '--output',
  'build/seo/search-console-lot15-report.json',
);
const markdownPath = argumentValue(
  '--markdown',
  'build/seo/search-console-lot15-report.md',
);
const requestedSiteUrl =
  process.env.SEO_GSC_SITE_URL ?? config.searchConsoleSiteUrl;
const generatedAt = new Date().toISOString();
let report;
let workflowState = 'error';
let workflowDescription = 'Search Console inaccessible';

try {
  const metrics = await fetchSearchConsoleMetrics({
    config,
    directAccessToken: process.env.SEO_GOOGLE_ACCESS_TOKEN ?? '',
    serviceAccountJson:
      process.env.SEO_GOOGLE_SERVICE_ACCOUNT_JSON ??
      process.env.GOOGLE_SERVICE_ACCOUNT_JSON ??
      '',
    siteUrl: requestedSiteUrl,
  });
  const hasData =
    metrics.current.totals.impressions > 0 || metrics.current.totals.clicks > 0;
  report = {
    schemaVersion: 1,
    lot: 15,
    generatedAt,
    status: 'available',
    dataStatus: hasData ? 'data-present' : 'zero-data-valid',
    requestedSiteUrl,
    ...metrics,
  };
  workflowState = 'success';
  workflowDescription = hasData
    ? `Search Console disponible (${metrics.current.totals.impressions} impressions)`
    : 'Search Console disponible, aucune impression sur la période';
} catch (error) {
  const errorCode =
    error instanceof SearchConsoleAccessError ? error.code : 'unexpected_error';
  report = {
    schemaVersion: 1,
    lot: 15,
    generatedAt,
    status: 'blocked',
    requestedSiteUrl,
    errorCode,
    errorMessage: safeErrorMessage(error),
    upstreamDetails:
      error instanceof SearchConsoleAccessError ? error.details : {},
    remediation: remediationFor(errorCode),
  };
  workflowState = errorCode === 'api_disabled' ? 'pending' : 'failure';
  workflowDescription =
    errorCode === 'api_disabled'
      ? 'Search Console API à activer dans le projet Google'
      : `Search Console bloquée : ${errorCode}`;
}

await writeJsonFile(outputPath, report);
await fs.mkdir(path.dirname(markdownPath), { recursive: true });
await fs.writeFile(markdownPath, `${markdownFor(report)}\n`, 'utf8');

if (process.env.GITHUB_OUTPUT) {
  await fs.appendFile(
    process.env.GITHUB_OUTPUT,
    `state=${workflowState}\ndescription=${workflowDescription.slice(0, 140)}\nstatus=${report.status}\n`,
  );
}

console.log(`Search Console lot 15: ${workflowState} — ${workflowDescription}`);
if (report.status !== 'available' && process.argv.includes('--enforce')) {
  process.exitCode = 1;
}
