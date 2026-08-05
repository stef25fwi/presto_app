import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lighthouse-lot13-'));
const reportPath = path.join(tempDir, 'report.json');
const manifestPath = path.join(tempDir, 'manifest.json');
const outputJson = path.join(tempDir, 'summary.json');
const outputMarkdown = path.join(tempDir, 'summary.md');

const report = {
  finalDisplayedUrl: 'https://ilipresto.fr/',
  fetchTime: '2026-08-05T12:00:00.000Z',
  categories: {
    performance: {score: 0.9},
    seo: {score: 1},
    accessibility: {score: 0.95},
    'best-practices': {score: 0.95},
  },
  audits: {
    'first-contentful-paint': {numericValue: 1800},
    'largest-contentful-paint': {numericValue: 2600},
    'cumulative-layout-shift': {numericValue: 0.05},
    'total-blocking-time': {numericValue: 250},
    'speed-index': {numericValue: 3200},
  },
};

fs.writeFileSync(reportPath, JSON.stringify(report));
fs.writeFileSync(manifestPath, JSON.stringify([{
  url: 'https://ilipresto.fr/',
  isRepresentativeRun: true,
  jsonPath: reportPath,
  htmlPath: path.join(tempDir, 'report.html'),
}]));

const run = spawnSync(process.execPath, [
  'tools/performance/build_lighthouse_baseline.mjs',
  '--profile', 'mobile',
  '--manifest', manifestPath,
  '--output-json', outputJson,
  '--output-markdown', outputMarkdown,
  '--reference-sha', 'test-sha',
], {cwd: process.cwd(), encoding: 'utf8'});

assert.equal(run.status, 0, run.stderr || run.stdout);
const summary = JSON.parse(fs.readFileSync(outputJson, 'utf8'));
assert.equal(summary.lot, 13);
assert.equal(summary.profile, 'mobile');
assert.equal(summary.status, 'passed');
assert.equal(summary.referenceSha, 'test-sha');
assert.equal(summary.pages.length, 1);
assert.match(fs.readFileSync(outputMarkdown, 'utf8'), /Lighthouse mobile — lot 13/);

console.log('Lighthouse lot 13 baseline tooling: OK');
