import { pathToFileURL } from 'node:url';

import { fetchGa4Metrics } from './fetch_ga4_metrics.mjs';
import { fetchSearchConsoleMetrics } from './fetch_search_console_metrics.mjs';
import { monitorPublicSeo } from './monitor_public_seo.mjs';
import {
  loadSeoMonitoringConfig,
  safeErrorMessage,
  writeJsonFile,
  writeTextFile,
} from './seo_monitoring_utils.mjs';

function addAlert(alerts, severity, code, message, evidence = {}) {
  alerts.push({ severity, code, message, evidence });
}

function evaluateSearchConsole(config, searchConsole, alerts) {
  if (searchConsole.status !== 'available') return;
  const thresholds = config.thresholds;
  const previous = searchConsole.previous.totals;
  const changes = searchConsole.changes;

  if (
    previous.clicks >= thresholds.minimumPreviousClicksForTrend &&
    changes.clicksPercent <= -thresholds.clicksDropPercent
  ) {
    addAlert(
      alerts,
      'warning',
      'gsc_clicks_drop',
      `Les clics organiques reculent de ${Math.abs(changes.clicksPercent)} %.`,
      { current: searchConsole.current.totals.clicks, previous: previous.clicks },
    );
  }
  if (
    previous.impressions >= thresholds.minimumPreviousImpressionsForTrend &&
    changes.impressionsPercent <= -thresholds.impressionsDropPercent
  ) {
    addAlert(
      alerts,
      'warning',
      'gsc_impressions_drop',
      `Les impressions organiques reculent de ${Math.abs(
        changes.impressionsPercent,
      )} %.`,
      {
        current: searchConsole.current.totals.impressions,
        previous: previous.impressions,
      },
    );
  }
  if (changes.ctrPercentagePoints <= -thresholds.ctrDropPercentagePoints) {
    addAlert(
      alerts,
      'warning',
      'gsc_ctr_drop',
      `Le CTR organique perd ${Math.abs(changes.ctrPercentagePoints)} point(s).`,
      {
        current: searchConsole.current.totals.ctrPercent,
        previous: previous.ctrPercent,
      },
    );
  }
  if (changes.averagePositionDelta >= thresholds.averagePositionLoss) {
    addAlert(
      alerts,
      'warning',
      'gsc_position_loss',
      `La position moyenne se dégrade de ${changes.averagePositionDelta}.`,
      {
        current: searchConsole.current.totals.averagePosition,
        previous: previous.averagePosition,
      },
    );
  }
}

function evaluateGa4(config, ga4, alerts) {
  if (ga4.status !== 'available') return;
  const thresholds = config.thresholds;
  const previous = ga4.previous.totals;
  const changes = ga4.changes;

  if (
    previous.sessions >= thresholds.minimumPreviousSessionsForTrend &&
    changes.sessionsPercent <= -thresholds.organicSessionsDropPercent
  ) {
    addAlert(
      alerts,
      'warning',
      'ga4_organic_sessions_drop',
      `Les sessions Organic Search reculent de ${Math.abs(
        changes.sessionsPercent,
      )} %.`,
      { current: ga4.current.totals.sessions, previous: previous.sessions },
    );
  }
  if (
    previous.organicKeyEvents > 0 &&
    changes.organicKeyEventsPercent <= -thresholds.organicKeyEventsDropPercent
  ) {
    addAlert(
      alerts,
      'warning',
      'ga4_organic_key_events_drop',
      `Les conversions organiques reculent de ${Math.abs(
        changes.organicKeyEventsPercent,
      )} %.`,
      {
        current: ga4.current.totals.organicKeyEvents,
        previous: previous.organicKeyEvents,
      },
    );
  }
}

function recommendationsFor(alerts) {
  const mapping = {
    production_seo_failure:
      'Corriger en priorité les URL, canonicals, métadonnées ou fichiers d’indexation signalés par le contrôle de production.',
    gsc_clicks_drop:
      'Comparer les pages et requêtes en baisse, puis retravailler title, meta description, maillage et adéquation à l’intention.',
    gsc_impressions_drop:
      'Contrôler l’indexation, les positions et la couverture sémantique des pages dont les impressions reculent.',
    gsc_ctr_drop:
      'Optimiser les snippets des pages à fortes impressions et faible CTR sans modifier leur positionnement national.',
    gsc_position_loss:
      'Identifier les requêtes perdant des positions et renforcer contenu, liens internes, fraîcheur et preuves de confiance.',
    ga4_organic_sessions_drop:
      'Vérifier la cohérence Search Console/GA4, les pages d’entrée et les éventuelles ruptures de consentement ou de mesure.',
    ga4_organic_key_events_drop:
      'Analyser le tunnel organique entre landing, inscription, première valeur et contact afin de corriger le point de fuite.',
    external_data_missing:
      'Vérifier les droits Search Console et GA4 du compte fédéré WIF utilisé par GitHub Actions.',
  };
  return [...new Set(alerts.map((alert) => mapping[alert.code]).filter(Boolean))];
}

function markdownReport(report) {
  const lines = [
    '# Suivi SEO continu — iliprestō',
    '',
    `- Statut : **${report.status}**`,
    `- Généré le : ${report.generatedAt}`,
    `- Pages saines : ${report.productionHealth.healthyPages}/${report.productionHealth.totalPages}`,
    `- Disponibilité SEO : ${report.productionHealth.availabilityPercent} %`,
    `- Search Console : ${report.searchConsole.status}`,
    `- GA4 : ${report.ga4.status}`,
    '',
    '## Alertes',
    '',
  ];
  if (report.alerts.length === 0) lines.push('Aucune alerte active.');
  else {
    for (const alert of report.alerts) {
      lines.push(`- **${alert.severity}** — ${alert.message} (${alert.code})`);
    }
  }
  lines.push('', '## Recommandations', '');
  if (report.recommendations.length === 0) {
    lines.push('Poursuivre le cycle mensuel de mesure et d’amélioration.');
  } else {
    for (const recommendation of report.recommendations) {
      lines.push(`- ${recommendation}`);
    }
  }
  lines.push('');
  return `${lines.join('\n')}\n`;
}

export async function buildSeoMonitoringReport({
  config,
  requireExternalData = false,
}) {
  const productionHealth = await monitorPublicSeo({ config });
  const directAccessToken = process.env.SEO_GOOGLE_ACCESS_TOKEN ?? '';
  const serviceAccountJson =
    process.env.SEO_GOOGLE_SERVICE_ACCOUNT_JSON ??
    process.env.GOOGLE_SERVICE_ACCOUNT_JSON ??
    '';
  const ga4PropertyId = process.env.SEO_GA4_PROPERTY_ID ?? '';
  const hasGoogleAuthentication =
    directAccessToken.trim().length > 0 || serviceAccountJson.trim().length > 0;

  let searchConsole = { status: 'not_configured' };
  let ga4 = { status: 'not_configured' };
  if (hasGoogleAuthentication) {
    try {
      searchConsole = await fetchSearchConsoleMetrics({
        config,
        directAccessToken,
        serviceAccountJson,
        siteUrl: process.env.SEO_GSC_SITE_URL ?? config.searchConsoleSiteUrl,
      });
    } catch (error) {
      searchConsole = { status: 'error', error: safeErrorMessage(error) };
    }
    try {
      ga4 = await fetchGa4Metrics({
        config,
        directAccessToken,
        serviceAccountJson,
        propertyId: ga4PropertyId,
      });
    } catch (error) {
      ga4 = { status: 'error', error: safeErrorMessage(error) };
    }
  }

  const alerts = [];
  if (productionHealth.status === 'critical') {
    addAlert(
      alerts,
      'critical',
      'production_seo_failure',
      `${productionHealth.errors.length} régression(s) SEO détectée(s) en production.`,
      { errors: productionHealth.errors },
    );
  }
  evaluateSearchConsole(config, searchConsole, alerts);
  evaluateGa4(config, ga4, alerts);

  if (
    requireExternalData &&
    (searchConsole.status !== 'available' || ga4.status !== 'available')
  ) {
    addAlert(
      alerts,
      'critical',
      'external_data_missing',
      'Les données Search Console ou GA4 ne sont pas disponibles.',
      { searchConsole: searchConsole.status, ga4: ga4.status },
    );
  }

  const status = alerts.some((alert) => alert.severity === 'critical')
    ? 'critical'
    : alerts.length > 0 || productionHealth.status === 'warning'
      ? 'warning'
      : 'healthy';
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    status,
    siteUrl: config.siteUrl,
    measurementId: config.ga4MeasurementId,
    productionHealth,
    searchConsole,
    ga4,
    alerts,
    recommendations: recommendationsFor(alerts),
  };
}

async function runCli() {
  const config = await loadSeoMonitoringConfig();
  const enforce = process.argv.includes('--enforce');
  const requireExternalData = process.argv.includes('--require-external-data');
  const outputIndex = process.argv.indexOf('--output');
  const outputPath =
    outputIndex >= 0
      ? process.argv[outputIndex + 1]
      : 'build/seo/seo-monitoring-report.json';
  const markdownPath = outputPath.replace(/\.json$/u, '.md');
  try {
    const report = await buildSeoMonitoringReport({
      config,
      requireExternalData,
    });
    await writeJsonFile(outputPath, report);
    await writeTextFile(markdownPath, markdownReport(report));
    console.log(
      `SEO continuous monitoring: ${report.status} (${report.alerts.length} alertes)`,
    );
    if (enforce && report.status === 'critical') process.exitCode = 1;
  } catch (error) {
    console.error(safeErrorMessage(error));
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await runCli();
}
