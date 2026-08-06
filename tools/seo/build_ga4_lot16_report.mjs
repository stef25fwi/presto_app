#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import { fetchGa4Metrics } from './fetch_ga4_metrics.mjs';
import {
  loadSeoMonitoringConfig,
  safeErrorMessage,
  writeJsonFile,
} from './seo_monitoring_utils.mjs';

const STATUS_CONTEXT = 'quality/ga4-organic-lot16';

function argumentValue(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

export function classifyGa4Error(error) {
  const message = safeErrorMessage(error);
  const normalized = message.toLowerCase();

  if (
    normalized.includes('has not been used') ||
    normalized.includes('is disabled') ||
    normalized.includes('service_disabled') ||
    normalized.includes('service disabled')
  ) {
    return 'api_disabled';
  }
  if (
    normalized.includes('no ga4 property visible') ||
    normalized.includes('does not have sufficient permissions') ||
    normalized.includes('permission denied') ||
    normalized.includes('permission_denied') ||
    normalized.includes('caller does not have permission')
  ) {
    return 'property_not_granted';
  }
  if (normalized.includes('measurement id is missing')) {
    return 'measurement_id_missing';
  }
  if (
    normalized.includes('property') &&
    (normalized.includes('not found') ||
      normalized.includes('invalid argument') ||
      normalized.includes('(404)'))
  ) {
    return 'invalid_property';
  }
  if (
    normalized.includes('unauthenticated') ||
    normalized.includes('invalid credentials') ||
    normalized.includes('(401)')
  ) {
    return 'authentication_failed';
  }
  return 'unexpected_error';
}

export function remediationFor(code) {
  switch (code) {
    case 'api_disabled':
      return 'Activer `analyticsdata.googleapis.com` et `analyticsadmin.googleapis.com` dans le projet Google Cloud `presto-app-74abe`, puis relancer le workflow.';
    case 'property_not_granted':
      return 'Dans Google Analytics, ouvrir Administration → Gestion des accès à la propriété, puis ajouter `github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com` avec le rôle Lecteur sur la propriété contenant le flux Web `G-NT4PEHQ3CJ`.';
    case 'measurement_id_missing':
      return 'Renseigner le Measurement ID GA4 dans `config/seo-monitoring.json`.';
    case 'invalid_property':
      return 'Vérifier la variable d’environnement GitHub `SEO_GA4_PROPERTY_ID`. Elle doit contenir uniquement l’identifiant numérique de la propriété GA4, sans préfixe `properties/`.';
    case 'authentication_failed':
      return 'Vérifier les secrets `WIF_PROVIDER` et `WIF_SERVICE_ACCOUNT` de l’environnement GitHub `recaptcha`.';
    default:
      return 'Consulter le message amont dans l’artefact, corriger l’accès Analytics, puis relancer le workflow.';
  }
}

function hasOrganicData(metrics) {
  return (
    Number(metrics.current?.totals?.sessions ?? 0) > 0 ||
    Number(metrics.current?.totals?.engagedSessions ?? 0) > 0 ||
    Number(metrics.current?.totals?.organicKeyEvents ?? 0) > 0 ||
    (metrics.current?.topLandingPages?.length ?? 0) > 0
  );
}

export async function buildGa4Lot16Report({
  config,
  fetchMetrics = fetchGa4Metrics,
  directAccessToken = '',
  serviceAccountJson = '',
  propertyId = '',
  now = new Date(),
}) {
  const generatedAt = now.toISOString();
  try {
    const metrics = await fetchMetrics({
      config,
      directAccessToken,
      serviceAccountJson,
      propertyId,
      now,
    });
    const dataPresent = hasOrganicData(metrics);
    return {
      report: {
        schemaVersion: 1,
        lot: 16,
        statusContext: STATUS_CONTEXT,
        generatedAt,
        status: 'available',
        dataStatus: dataPresent ? 'data-present' : 'zero-data-valid',
        ...metrics,
      },
      workflowState: 'success',
      workflowDescription: dataPresent
        ? `GA4 Organic Search disponible (${metrics.current.totals.sessions} sessions)`
        : 'GA4 disponible, aucune session organique sur la période',
    };
  } catch (error) {
    const errorCode = classifyGa4Error(error);
    return {
      report: {
        schemaVersion: 1,
        lot: 16,
        statusContext: STATUS_CONTEXT,
        generatedAt,
        status: 'blocked',
        measurementId: config.ga4MeasurementId,
        requestedPropertyId: String(propertyId || '').trim() || null,
        errorCode,
        errorMessage: safeErrorMessage(error),
        remediation: remediationFor(errorCode),
      },
      workflowState: errorCode === 'api_disabled' ? 'pending' : 'failure',
      workflowDescription:
        errorCode === 'api_disabled'
          ? 'GA4 APIs à activer dans le projet Google'
          : `GA4 Organic Search bloqué : ${errorCode}`,
    };
  }
}

function metric(value) {
  return Number(value ?? 0);
}

export function markdownFor(report) {
  const lines = [
    '# GA4 Organic Search — lot 16',
    '',
    `- Statut : **${report.status}**`,
    `- Généré le : **${report.generatedAt}**`,
    `- Contexte GitHub : **${report.statusContext}**`,
    `- Measurement ID : **${report.measurementId}**`,
  ];

  if (report.status === 'available') {
    const current = report.current;
    const previous = report.previous;
    lines.push(
      `- Property ID : **${report.propertyId}**`,
      `- Données : **${report.dataStatus}**`,
      `- Métrique d’événement clé : **${report.keyEventMetric}**`,
      '',
      '| Période | Sessions | Sessions engagées | Taux d’engagement | Événements clés |',
      '|---|---:|---:|---:|---:|',
      `| Actuelle | ${metric(current.totals.sessions)} | ${metric(current.totals.engagedSessions)} | ${metric(current.totals.engagementRatePercent)} % | ${metric(current.totals.organicKeyEvents)} |`,
      `| Précédente | ${metric(previous.totals.sessions)} | ${metric(previous.totals.engagedSessions)} | ${metric(previous.totals.engagementRatePercent)} % | ${metric(previous.totals.organicKeyEvents)} |`,
      '',
      '## Landing pages organiques',
      '',
    );
    if ((current.topLandingPages ?? []).length === 0) {
      lines.push('Aucune landing page organique sur la période.');
    } else {
      lines.push('| Page | Sessions | Sessions engagées | Événements clés |', '|---|---:|---:|---:|');
      for (const row of current.topLandingPages.slice(0, 10)) {
        lines.push(
          `| ${row.landingPagePlusQueryString || '(non défini)'} | ${metric(row.sessions)} | ${metric(row.engagedSessions)} | ${metric(row[report.keyEventMetric])} |`,
        );
      }
    }
    lines.push('', '## Événements de conversion organiques', '');
    if ((current.conversionEvents ?? []).length === 0) {
      lines.push('Aucun événement de conversion organique sur la période.');
    } else {
      lines.push('| Événement | Nombre |', '|---|---:|');
      for (const row of current.conversionEvents) {
        lines.push(`| ${row.eventName} | ${metric(row.eventCount)} |`);
      }
    }
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

async function runCli() {
  const config = await loadSeoMonitoringConfig();
  const outputPath = argumentValue(
    '--output',
    'build/seo/ga4-organic-lot16-report.json',
  );
  const markdownPath = argumentValue(
    '--markdown',
    'build/seo/ga4-organic-lot16-report.md',
  );
  const result = await buildGa4Lot16Report({
    config,
    directAccessToken: process.env.SEO_GOOGLE_ACCESS_TOKEN ?? '',
    serviceAccountJson:
      process.env.SEO_GOOGLE_SERVICE_ACCOUNT_JSON ??
      process.env.GOOGLE_SERVICE_ACCOUNT_JSON ??
      '',
    propertyId: process.env.SEO_GA4_PROPERTY_ID ?? '',
  });

  await writeJsonFile(outputPath, result.report);
  await fs.mkdir(path.dirname(markdownPath), { recursive: true });
  await fs.writeFile(markdownPath, `${markdownFor(result.report)}\n`, 'utf8');

  if (process.env.GITHUB_OUTPUT) {
    await fs.appendFile(
      process.env.GITHUB_OUTPUT,
      `state=${result.workflowState}\ndescription=${result.workflowDescription.slice(0, 140)}\nstatus=${result.report.status}\n`,
    );
  }

  console.log(`GA4 lot 16: ${result.workflowState} — ${result.workflowDescription}`);
  if (result.report.status !== 'available' && process.argv.includes('--enforce')) {
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await runCli();
}
