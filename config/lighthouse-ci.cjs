const fs = require('node:fs');
const path = require('node:path');

const profile = process.env.LIGHTHOUSE_PROFILE || 'mobile';
const baseUrl = (process.env.LIGHTHOUSE_BASE_URL || 'https://ilipresto.fr').replace(/\/+$/, '');
const thresholdsPath = path.join(__dirname, 'lighthouse-thresholds.json');
const thresholds = JSON.parse(fs.readFileSync(thresholdsPath, 'utf8')).profiles[profile];

if (!thresholds) {
  throw new Error(`Unknown Lighthouse profile: ${profile}`);
}

const pagePaths = [
  '/',
  '/trouver-une-personne-disponible/',
  '/guides/creer-micro-entreprise-services/',
  '/guadeloupe',
];

const maxNumericValue = (value) => ['error', {maxNumericValue: value, aggregationMethod: 'median'}];
const minScore = (value) => ['error', {minScore: value, aggregationMethod: 'median'}];

module.exports = {
  ci: {
    collect: {
      url: pagePaths.map((pagePath) => new URL(pagePath, `${baseUrl}/`).toString()),
      numberOfRuns: 3,
      settings: {
        ...(profile === 'desktop' ? {preset: 'desktop'} : {}),
        onlyCategories: ['performance', 'accessibility', 'best-practices', 'seo'],
        chromeFlags: '--headless --no-sandbox --disable-dev-shm-usage',
        maxWaitForFcp: 45000,
        maxWaitForLoad: 60000,
      },
    },
    assert: {
      assertions: {
        'categories:performance': minScore(thresholds.performanceScoreMin),
        'categories:seo': minScore(thresholds.seoScoreMin),
        'categories:accessibility': minScore(thresholds.accessibilityScoreMin),
        'categories:best-practices': minScore(thresholds.bestPracticesScoreMin),
        'first-contentful-paint': maxNumericValue(thresholds.firstContentfulPaintMsMax),
        'largest-contentful-paint': maxNumericValue(thresholds.largestContentfulPaintMsMax),
        'cumulative-layout-shift': maxNumericValue(thresholds.cumulativeLayoutShiftMax),
        'total-blocking-time': maxNumericValue(thresholds.totalBlockingTimeMsMax),
        'speed-index': maxNumericValue(thresholds.speedIndexMsMax),
      },
    },
    upload: {
      target: 'filesystem',
      outputDir: `build/quality/lighthouse/${profile}`,
      reportFilenamePattern: `${profile}-%%HOSTNAME%%-%%PATHNAME%%-%%DATETIME%%.report.%%EXTENSION%%`,
    },
  },
};
