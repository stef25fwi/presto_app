import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {fileURLToPath} from 'node:url';

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined) {
      throw new Error(`Invalid argument near ${key ?? '<end>'}`);
    }
    args[key.slice(2)] = value;
  }
  return args;
}

function resolveReportPath(manifestPath, reportPath) {
  if (path.isAbsolute(reportPath)) return reportPath;
  return path.resolve(path.dirname(manifestPath), reportPath);
}

function metric(audits, id) {
  const value = audits?.[id]?.numericValue;
  return Number.isFinite(value) ? value : null;
}

function formatMs(value) {
  return value === null ? 'n/a' : `${Math.round(value)} ms`;
}

function formatCls(value) {
  return value === null ? 'n/a' : value.toFixed(3);
}

function isWithin(value, maximum) {
  return value !== null && value <= maximum;
}

const args = parseArgs(process.argv.slice(2));
const profile = args.profile || process.env.LIGHTHOUSE_PROFILE || 'mobile';
const manifestPath = path.resolve(args.manifest || `build/quality/lighthouse/${profile}/manifest.json`);
const outputJson = path.resolve(args['output-json'] || `build/quality/lighthouse/${profile}/summary.json`);
const outputMarkdown = path.resolve(args['output-markdown'] || `build/quality/lighthouse/${profile}/summary.md`);
const referenceSha = args['reference-sha'] || process.env.LIGHTHOUSE_REFERENCE_SHA || process.env.GITHUB_SHA || 'unknown';
const runSha = process.env.GITHUB_SHA || referenceSha;

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const thresholdsFile = path.resolve(scriptDir, '../../config/lighthouse-thresholds.json');
const thresholdsRegistry = JSON.parse(fs.readFileSync(thresholdsFile, 'utf8'));
const thresholds = thresholdsRegistry.profiles?.[profile];
if (!thresholds) throw new Error(`Unknown Lighthouse profile: ${profile}`);

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const representative = manifest.filter((entry) => entry.isRepresentativeRun);
if (representative.length === 0) throw new Error(`No representative Lighthouse runs in ${manifestPath}`);

const pages = representative.map((entry) => {
  const reportPath = resolveReportPath(manifestPath, entry.jsonPath);
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const categories = report.categories || {};
  const audits = report.audits || {};
  const values = {
    performanceScore: categories.performance?.score ?? 0,
    seoScore: categories.seo?.score ?? 0,
    accessibilityScore: categories.accessibility?.score ?? 0,
    bestPracticesScore: categories['best-practices']?.score ?? 0,
    firstContentfulPaintMs: metric(audits, 'first-contentful-paint'),
    largestContentfulPaintMs: metric(audits, 'largest-contentful-paint'),
    cumulativeLayoutShift: metric(audits, 'cumulative-layout-shift'),
    totalBlockingTimeMs: metric(audits, 'total-blocking-time'),
    speedIndexMs: metric(audits, 'speed-index'),
  };
  const checks = {
    performanceScore: values.performanceScore >= thresholds.performanceScoreMin,
    seoScore: values.seoScore >= thresholds.seoScoreMin,
    accessibilityScore: values.accessibilityScore >= thresholds.accessibilityScoreMin,
    bestPracticesScore: values.bestPracticesScore >= thresholds.bestPracticesScoreMin,
    firstContentfulPaint: isWithin(values.firstContentfulPaintMs, thresholds.firstContentfulPaintMsMax),
    largestContentfulPaint: isWithin(values.largestContentfulPaintMs, thresholds.largestContentfulPaintMsMax),
    cumulativeLayoutShift: isWithin(values.cumulativeLayoutShift, thresholds.cumulativeLayoutShiftMax),
    totalBlockingTime: isWithin(values.totalBlockingTimeMs, thresholds.totalBlockingTimeMsMax),
    speedIndex: isWithin(values.speedIndexMs, thresholds.speedIndexMsMax),
  };
  return {
    url: report.finalDisplayedUrl || report.finalUrl || entry.url,
    fetchTime: report.fetchTime,
    values,
    checks,
    passed: Object.values(checks).every(Boolean),
    report: {
      json: entry.jsonPath,
      html: entry.htmlPath,
    },
  };
});

const passed = pages.every((page) => page.passed);
const result = {
  schemaVersion: 1,
  lot: 13,
  name: 'Baseline Lighthouse Performance',
  profile,
  status: passed ? 'passed' : 'failed',
  generatedAt: new Date().toISOString(),
  baseUrl: process.env.LIGHTHOUSE_BASE_URL || 'https://ilipresto.fr',
  referenceSha,
  runSha,
  thresholds,
  pages,
};

fs.mkdirSync(path.dirname(outputJson), {recursive: true});
fs.mkdirSync(path.dirname(outputMarkdown), {recursive: true});
fs.writeFileSync(outputJson, `${JSON.stringify(result, null, 2)}\n`);

const lines = [
  `## Lighthouse ${profile} — lot 13`,
  '',
  `- Statut : **${passed ? 'PASS' : 'FAIL'}**`,
  `- SHA de référence : \`${referenceSha}\``,
  `- SHA du workflow : \`${runSha}\``,
  '',
  '| Page | Performance | SEO | Accessibilité | Bonnes pratiques | FCP | LCP | CLS | TBT | Speed Index | Résultat |',
  '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|',
];

for (const page of pages) {
  const values = page.values;
  lines.push(`| ${page.url} | ${Math.round(values.performanceScore * 100)} | ${Math.round(values.seoScore * 100)} | ${Math.round(values.accessibilityScore * 100)} | ${Math.round(values.bestPracticesScore * 100)} | ${formatMs(values.firstContentfulPaintMs)} | ${formatMs(values.largestContentfulPaintMs)} | ${formatCls(values.cumulativeLayoutShift)} | ${formatMs(values.totalBlockingTimeMs)} | ${formatMs(values.speedIndexMs)} | ${page.passed ? '✅' : '❌'} |`);
}

lines.push('', 'Les rapports HTML et JSON complets sont conservés dans l’artefact GitHub Actions du même profil.', '');
fs.writeFileSync(outputMarkdown, `${lines.join('\n')}\n`);
console.log(`Lighthouse ${profile}: ${passed ? 'PASS' : 'FAIL'} (${pages.length} pages)`);
