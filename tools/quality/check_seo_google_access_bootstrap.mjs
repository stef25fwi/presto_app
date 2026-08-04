#!/usr/bin/env node

import fs from 'node:fs';

const scriptPath = 'tools/seo/bootstrap_google_measurement_access.sh';
const docsPath = 'docs/seo/google-measurement-access-bootstrap.md';
const failures = [];

function read(path) {
  if (!fs.existsSync(path)) {
    failures.push(`missing file: ${path}`);
    return '';
  }
  return fs.readFileSync(path, 'utf8');
}

function requireText(content, token, label) {
  if (!content.includes(token)) failures.push(`missing ${label}: ${token}`);
}

function forbidText(content, token, label) {
  if (content.includes(token)) failures.push(`forbidden ${label}: ${token}`);
}

const script = read(scriptPath);
const docs = read(docsPath);

requireText(script, 'set -euo pipefail', 'strict shell mode');
requireText(script, 'presto-app-74abe', 'Google Cloud project');
requireText(
  script,
  'github-firebase-deploy@${PROJECT_ID}.iam.gserviceaccount.com',
  'WIF service account',
);
for (const api of [
  'searchconsole.googleapis.com',
  'analyticsadmin.googleapis.com',
  'analyticsdata.googleapis.com',
]) {
  requireText(script, api, `required API ${api}`);
  requireText(docs, api, `documented API ${api}`);
}
requireText(
  script,
  'roles/serviceusage.serviceUsageConsumer',
  'least-privilege API consumer role',
);
forbidText(
  script,
  'roles/serviceusage.serviceUsageAdmin',
  'persistent Service Usage Admin grant',
);
forbidText(script, 'service-account keys create', 'service account key creation');
forbidText(script, '-----BEGIN PRIVATE KEY-----', 'embedded private key');
requireText(script, 'Accès complet', 'Search Console permission');
requireText(script, 'rôle Lecteur', 'GA4 Viewer permission');
requireText(script, '#1173', 'automatic issue closure criterion');
requireText(docs, 'AUTH_PERMISSION_DENIED', 'observed failure evidence');
requireText(docs, 'Accès complet', 'Search Console access instructions');
requireText(docs, 'Lecteur', 'GA4 access instructions');
requireText(docs, '12/12', 'production health criterion');
requireText(docs, 'Search Console : `available`', 'Search Console success criterion');
requireText(docs, 'GA4 : `available`', 'GA4 success criterion');

if (failures.length) {
  console.error('SEO Google access bootstrap: FAIL');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log('SEO Google access bootstrap: OK');
