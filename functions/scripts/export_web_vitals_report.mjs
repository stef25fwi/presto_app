#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const outputDir = path.resolve(process.env.CWV_OUTPUT_DIR || '../build/quality/core-web-vitals');
const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || 'presto-app-74abe';
const now = Date.now();

if (getApps().length === 0) {
  initializeApp({ credential: applicationDefault(), projectId });
}

const snapshot = await getFirestore().collection('web_vitals_reports').doc('latest').get();
let report;
if (!snapshot.exists) {
  report = {
    schemaVersion: 1,
    status: 'insufficient-data',
    reason: 'report_not_generated_yet',
    generatedAt: now,
    totalSamples: 0,
    devices: {},
  };
} else {
  report = snapshot.data();
}

const generatedAt = Number(report.generatedAt || 0);
const ageHours = generatedAt > 0 ? Math.round(((now - generatedAt) / 3_600_000) * 10) / 10 : null;
const normalized = {
  ...report,
  exportedAt: now,
  reportAgeHours: ageHours,
  stale: ageHours === null || ageHours > 36,
};

fs.mkdirSync(outputDir, { recursive: true });
fs.writeFileSync(
  path.join(outputDir, 'report.json'),
  `${JSON.stringify(normalized, null, 2)}\n`,
);

const metricLabel = { LCP: 'LCP', INP: 'INP', CLS: 'CLS' };
const lines = [
  '# Core Web Vitals terrain — lot 14',
  '',
  `- Statut : **${normalized.status || 'insufficient-data'}**`,
  `- Échantillons : **${Number(normalized.totalSamples || 0)}**`,
  `- Fenêtre : **${Number(normalized.windowDays || 28)} jours**`,
  `- Âge du rapport : **${ageHours === null ? 'indisponible' : `${ageHours} h`}**`,
  '',
  '| Appareil | Métrique | p75 | Seuil | Échantillons | Statut |',
  '|---|---|---:|---:|---:|---|',
];

for (const device of ['mobile', 'desktop']) {
  const deviceReport = normalized.devices?.[device];
  for (const metric of ['LCP', 'INP', 'CLS']) {
    const metricReport = deviceReport?.metrics?.[metric];
    lines.push([
      device,
      metricLabel[metric],
      metricReport?.p75 ?? '—',
      metricReport?.threshold ?? '—',
      metricReport?.sampleCount ?? 0,
      metricReport?.status ?? 'insufficient-data',
    ].join(' | ').replace(/^/, '| ').replace(/$/, ' |'));
  }
}

lines.push('', 'La certification exige les trois métriques au vert sur mobile et desktop avec le volume minimal configuré.', '');
fs.writeFileSync(path.join(outputDir, 'report.md'), lines.join('\n'));

const workflowState = normalized.stale
  ? 'pending'
  : normalized.status === 'pass'
    ? 'success'
    : normalized.status === 'fail'
      ? 'failure'
      : 'pending';
const description = normalized.stale
  ? 'Rapport terrain absent ou périmé'
  : normalized.status === 'pass'
    ? 'LCP, INP et CLS terrain au vert'
    : normalized.status === 'fail'
      ? 'Au moins un Core Web Vital dépasse le seuil'
      : `Données insuffisantes (${Number(normalized.totalSamples || 0)} échantillons)`;

if (process.env.GITHUB_OUTPUT) {
  fs.appendFileSync(process.env.GITHUB_OUTPUT, `state=${workflowState}\n`);
  fs.appendFileSync(process.env.GITHUB_OUTPUT, `description=${description}\n`);
}

console.log(`Core Web Vitals field report: ${workflowState} — ${description}`);
