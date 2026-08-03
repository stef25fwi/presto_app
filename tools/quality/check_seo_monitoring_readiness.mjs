#!/usr/bin/env node

import fs from 'node:fs';
import { spawnSync } from 'node:child_process';

const failures = [];
const read = (path) => {
  if (!fs.existsSync(path)) {
    failures.push(`missing file: ${path}`);
    return '';
  }
  return fs.readFileSync(path, 'utf8');
};
const requireText = (content, token, label) => {
  if (!content.includes(token)) failures.push(`missing ${label}: ${token}`);
};
const requireCondition = (condition, message) => {
  if (!condition) failures.push(message);
};

const configText = read('config/seo-monitoring.json');
const readinessText = read('quality/seo-monitoring-readiness.json');
const docs = read('docs/seo/monitoring-and-continuous-improvement.md');
const auth = read('tools/seo/google_service_account_auth.mjs');
const gsc = read('tools/seo/fetch_search_console_metrics.mjs');
const ga4 = read('tools/seo/fetch_ga4_metrics.mjs');
const publicMonitor = read('tools/seo/monitor_public_seo.mjs');
const report = read('tools/seo/build_seo_monitoring_report.mjs');
const workflow = read('.github/workflows/seo-continuous-monitoring.yml');
const prWorkflow = read('.github/workflows/seo-acquisition-readiness.yml');
const firebaseOptions = read('lib/firebase_options.dart');
const analyticsEvents = read('lib/services/product_analytics_events.dart');

let config = {};
let readiness = {};
try {
  config = JSON.parse(configText);
} catch {
  failures.push('config/seo-monitoring.json is not valid JSON');
}
try {
  readiness = JSON.parse(readinessText);
} catch {
  failures.push('quality/seo-monitoring-readiness.json is not valid JSON');
}

requireCondition(config.siteUrl === 'https://ilipresto.fr', 'canonical site URL is invalid');
requireCondition(
  config.searchConsoleSiteUrl === 'sc-domain:ilipresto.fr',
  'Search Console domain property is invalid',
);
requireCondition(config.ga4MeasurementId === 'G-NT4PEHQ3CJ', 'GA4 measurement ID is invalid');
requireText(firebaseOptions, "measurementId: 'G-NT4PEHQ3CJ'", 'Firebase GA4 alignment');

const pages = Array.isArray(config.monitoredPages) ? config.monitoredPages : [];
const paths = pages.map((page) => page.path);
const requiredPaths = [
  '/',
  '/a-propos',
  '/guides/comment-fonctionne-ilipresto',
  '/guadeloupe',
  '/martinique',
  '/guyane',
  '/mentions-legales',
  '/confidentialite',
  '/cgu',
  '/suppression-compte',
];
requireCondition(paths.length === 10, `expected 10 monitored pages, found ${paths.length}`);
requireCondition(new Set(paths).size === paths.length, 'monitored pages contain duplicates');
for (const path of requiredPaths) requireCondition(paths.includes(path), `monitored page missing: ${path}`);
for (const page of pages) {
  requireCondition(
    ['html', 'runtime-registry'].includes(page.validationMode),
    `invalid validation mode for ${page.path}`,
  );
}

const controls = Array.isArray(readiness.controls) ? readiness.controls : [];
requireCondition(readiness.status === 'verified', 'SEO monitoring readiness is not verified');
requireCondition(controls.length >= 10, 'SEO monitoring controls are incomplete');
for (const control of controls) {
  requireCondition(control.status === 'verified', `control not verified: ${control.id}`);
  requireCondition(Boolean(control.evidence), `control evidence missing: ${control.id}`);
}

for (const eventName of config.conversionEvents ?? []) {
  requireText(analyticsEvents, `name: '${eventName}'`, `analytics event ${eventName}`);
}

requireText(auth, 'directAccessToken', 'short-lived token support');
requireText(auth, 'RSA-SHA256', 'local service-account fallback');
requireText(gsc, 'webmasters.readonly', 'Search Console readonly scope');
requireText(gsc, '/searchAnalytics/query', 'Search Console query endpoint');
requireText(gsc, "dimensions: ['query']", 'query reporting');
requireText(gsc, "dimensions: ['page']", 'page reporting');
requireText(ga4, 'analyticsadmin.googleapis.com/v1beta/accountSummaries', 'GA4 property discovery');
requireText(ga4, 'webStreamData?.measurementId', 'GA4 measurement matching');
requireText(ga4, 'analyticsdata.googleapis.com/v1beta/properties', 'GA4 Data API endpoint');
requireText(ga4, 'Organic Search', 'organic channel filter');
requireText(ga4, 'landingPagePlusQueryString', 'landing page reporting');
requireText(publicMonitor, 'robots.txt', 'robots monitoring');
requireText(publicMonitor, 'sitemap.xml', 'sitemap monitoring');
requireText(publicMonitor, 'runtime-registry', 'runtime route registry monitoring');
requireText(report, 'gsc_clicks_drop', 'Search Console trend alert');
requireText(report, 'ga4_organic_sessions_drop', 'GA4 trend alert');
requireText(report, '--require-external-data', 'strict external-data mode');

requireText(workflow, 'schedule:', 'scheduled monitoring');
requireText(workflow, "cron: '17 10 * * *'", 'daily Guadeloupe schedule');
requireText(workflow, 'id-token: write', 'OIDC permission');
requireText(workflow, 'issues: write', 'issue alert permission');
requireText(workflow, 'google-github-actions/auth@v3', 'WIF authentication action');
requireText(workflow, 'secrets.WIF_PROVIDER', 'WIF provider wiring');
requireText(workflow, 'secrets.WIF_SERVICE_ACCOUNT', 'WIF service account wiring');
requireText(workflow, 'SEO_GOOGLE_ACCESS_TOKEN', 'short-lived token wiring');
requireText(workflow, 'SEO_GA4_PROPERTY_ID', 'optional GA4 override');
requireText(workflow, 'webmasters.readonly', 'Search Console token scope');
requireText(workflow, 'analytics.readonly', 'GA4 token scope');
requireText(workflow, 'build_seo_monitoring_report.mjs', 'monitoring report execution');
requireText(workflow, 'actions/upload-artifact@v4', 'report retention');
requireText(workflow, 'actions/github-script@v7', 'GitHub issue alerting');
requireText(prWorkflow, 'check_seo_monitoring_readiness.test.mjs', 'PR regression gate');
requireText(docs, 'Search Console', 'Search Console runbook');
requireText(docs, 'Workload Identity Federation', 'WIF runbook');
requireText(docs, 'SEO_GOOGLE_SERVICE_ACCOUNT_JSON', 'local fallback documentation');
requireText(docs, 'Revue hebdomadaire', 'weekly improvement cycle');
requireText(docs, 'Revue mensuelle', 'monthly improvement cycle');

for (const [path, content] of [
  ['config/seo-monitoring.json', configText],
  ['quality/seo-monitoring-readiness.json', readinessText],
  ['.github/workflows/seo-continuous-monitoring.yml', workflow],
]) {
  if (content.includes('-----BEGIN PRIVATE KEY-----')) {
    failures.push(`private key committed in ${path}`);
  }
}

for (const script of [
  'tools/seo/google_service_account_auth.mjs',
  'tools/seo/seo_monitoring_utils.mjs',
  'tools/seo/fetch_search_console_metrics.mjs',
  'tools/seo/fetch_ga4_metrics.mjs',
  'tools/seo/monitor_public_seo.mjs',
  'tools/seo/build_seo_monitoring_report.mjs',
]) {
  const result = spawnSync(process.execPath, ['--check', script], { encoding: 'utf8' });
  if (result.status !== 0) failures.push(`syntax error in ${script}: ${result.stderr.trim()}`);
}

if (failures.length) {
  console.error('SEO monitoring readiness: FAIL');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}
console.log(`SEO monitoring readiness: OK (${controls.length} controls, ${paths.length} pages)`);
