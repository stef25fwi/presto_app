import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const client = fs.readFileSync('web/web-vitals-rum.js', 'utf8');
const backend = fs.readFileSync('functions/src/modules/monitoring/web_vitals.ts', 'utf8');
const core = fs.readFileSync('functions/src/modules/monitoring/web_vitals_core.ts', 'utf8');
const functionsIndex = fs.readFileSync('functions/src/index.ts', 'utf8');
const buildWrapper = fs.readFileSync('tools/flutter_with_build_stamp.sh', 'utf8');

for (const token of [
  "observe('largest-contentful-paint'",
  "observe('layout-shift'",
  "observe('event'",
  "durationThreshold: 40",
  "navigator.globalPrivacyControl",
  "navigator.doNotTrack",
  "navigator.webdriver",
  "ilipresto-cwv-optout",
  "credentials: 'omit'",
  "text/plain;charset=UTF-8",
]) {
  assert.ok(client.includes(token), `missing RUM contract token: ${token}`);
}
assert.doesNotMatch(client, /document\.cookie|userId|email/i);
assert.match(client, /localStorage\.setItem\(optOutKey, '1'\)/);
assert.match(client, /europe-west1-presto-app-74abe\.cloudfunctions\.net\/collectWebVitals/);

assert.match(backend, /anonymous: true/);
assert.match(backend, /SAMPLE_RETENTION_MS = 35/);
assert.match(backend, /minimumSamplesPerMetric: 75/);
assert.match(backend, /windowDays: 28/);
assert.match(backend, /Sec-GPC/);
assert.match(backend, /DNT/);
assert.match(backend, /Buffer\.isBuffer/);
assert.match(core, /LCP: 2500/);
assert.match(core, /INP: 200/);
assert.match(core, /CLS: 0\.1/);
assert.match(functionsIndex, /collectWebVitals/);
assert.match(functionsIndex, /aggregateWebVitals28Days/);
assert.match(buildWrapper, /inject_web_vitals_rum\.mjs build\/web/);

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ilipresto-cwv-'));
fs.writeFileSync(path.join(tempRoot, 'web-vitals-rum.js'), '// rum');
fs.writeFileSync(path.join(tempRoot, 'index.html'), '<html><head></head><body></body></html>');
fs.mkdirSync(path.join(tempRoot, 'guide'));
fs.writeFileSync(path.join(tempRoot, 'guide', 'index.html'), '<html><head></head><body></body></html>');

const injection = spawnSync(process.execPath, [
  'tools/seo/inject_web_vitals_rum.mjs',
  tempRoot,
], { encoding: 'utf8' });
assert.equal(injection.status, 0, injection.stderr || injection.stdout);
for (const htmlPath of [
  path.join(tempRoot, 'index.html'),
  path.join(tempRoot, 'guide', 'index.html'),
]) {
  const html = fs.readFileSync(htmlPath, 'utf8');
  assert.equal((html.match(/web-vitals-rum\.js/g) || []).length, 1);
}

const secondInjection = spawnSync(process.execPath, [
  'tools/seo/inject_web_vitals_rum.mjs',
  tempRoot,
], { encoding: 'utf8' });
assert.equal(secondInjection.status, 0, secondInjection.stderr || secondInjection.stdout);
assert.equal((fs.readFileSync(path.join(tempRoot, 'index.html'), 'utf8').match(/web-vitals-rum\.js/g) || []).length, 1);

console.log('Core Web Vitals RUM lot 14 contract: OK');
