import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const checker = fileURLToPath(new URL('./check_mobile_readiness.mjs', import.meta.url));
const registry = new URL('../../quality/mobile_readiness.json', import.meta.url);
const sourceFor = (controls) => ({
  schema_version: 1,
  phase: 12,
  name: 'mobile_readiness',
  controls: controls.map(([id, status]) => ({ id, status, evidence: [] }))
});

function runChecker(t, source, enforce = false) {
  const cwd = mkdtempSync(join(tmpdir(), 'mobile-readiness-test-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  mkdirSync(join(cwd, 'quality'));
  const sourcePath = join(cwd, 'quality/mobile_readiness.json');
  const sourceText = `${JSON.stringify(source, null, 2)}\n`;
  writeFileSync(sourcePath, sourceText);
  const result = spawnSync(process.execPath, [checker, ...(enforce ? ['--enforce'] : [])], {
    cwd,
    encoding: 'utf8',
    timeout: 10000
  });
  assert.ifError(result.error);
  assert.equal(result.signal, null, result.stderr);
  assert.equal(readFileSync(sourcePath, 'utf8'), sourceText, 'the registry must not be modified');
  const reportPath = join(cwd, 'mobile-readiness-report.json');
  const report = existsSync(reportPath) ? JSON.parse(readFileSync(reportPath, 'utf8')) : null;
  if (report !== null) {
    assert.deepEqual(JSON.parse(result.stdout), report, 'stdout and the report file must match');
    assert.equal(Number.isNaN(Date.parse(report.generated_at)), false);
  }
  return { ...result, report };
}

const mixedSource = sourceFor([
  ['android-build', 'in_progress'],
  ['push-notifications', 'pending'],
  ['crash-reporting', 'implemented'],
  ['ios-build', 'in_progress'],
  ['optional-control', 'not_applicable']
]);
// Partial evidence must never promote an in-progress control to implemented.
mixedSource.controls[0].evidence = ['.github/workflows/release_android.yml'];
const mixedReport = {
  phase: 12,
  total: 5,
  implemented: 1,
  pending: 1,
  in_progress: 2,
  incomplete: 3,
  completion_percent: 20,
  pending_controls: ['push-notifications'],
  in_progress_controls: ['android-build', 'ios-build'],
  incomplete_controls: ['android-build', 'push-notifications', 'ios-build']
};

for (const enforce of [false, true]) {
  const mode = enforce ? '--enforce' : 'report-only';
  test(`mixed statuses produce an honest report (${mode})`, (t) => {
    const result = runChecker(t, mixedSource, enforce);
    assert.equal(result.status, enforce ? 2 : 0, result.stderr);
    assert.equal(result.stderr, '');
    assert.notEqual(result.report, null);
    const { generated_at, ...report } = result.report;
    assert.deepEqual(report, mixedReport);
  });

  for (const status of ['implemented', 'pending', 'in_progress', 'not_applicable']) {
    test(`${status} alone keeps its completion semantics (${mode})`, (t) => {
      const result = runChecker(t, sourceFor([['only-control', status]]), enforce);
      const incomplete = status === 'pending' || status === 'in_progress';
      assert.equal(result.status, enforce && incomplete ? 2 : 0, result.stderr);
      assert.equal(result.stderr, '');
      assert.notEqual(result.report, null);
      const { generated_at, ...report } = result.report;
      assert.deepEqual(report, {
        phase: 12,
        total: 1,
        implemented: Number(status === 'implemented'),
        pending: Number(status === 'pending'),
        in_progress: Number(status === 'in_progress'),
        incomplete: Number(incomplete),
        completion_percent: status === 'implemented' ? 100 : 0,
        pending_controls: status === 'pending' ? ['only-control'] : [],
        in_progress_controls: status === 'in_progress' ? ['only-control'] : [],
        incomplete_controls: incomplete ? ['only-control'] : []
      });
    });
  }

  test(`unknown statuses are still rejected (${mode})`, (t) => {
    const result = runChecker(t, sourceFor([
      ['valid-control', 'in_progress'],
      ['invalid-control', 'in-progress']
    ]), enforce);
    assert.equal(result.status, 1);
    assert.equal(result.stderr.trim(), 'Statuts invalides: invalid-control');
    assert.equal(result.stdout, '');
    assert.equal(result.report, null);
  });
}

test('implemented and not-applicable controls still pass enforcement', (t) => {
  const result = runChecker(t, sourceFor([
    ['finished', 'implemented'],
    ['out-of-scope', 'not_applicable']
  ]), true);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.report.incomplete, 0);
  assert.deepEqual(result.report.incomplete_controls, []);
  assert.equal(result.report.completion_percent, 50);
});

test('the repository registry is accepted without changing its statuses', (t) => {
  const original = readFileSync(registry, 'utf8');
  const source = JSON.parse(original);
  const byStatus = (status) => source.controls.filter((control) => control.status === status);
  const incomplete = source.controls.filter((control) =>
    ['pending', 'in_progress'].includes(control.status)
  );
  const normal = runChecker(t, source);
  const strict = runChecker(t, source, true);
  assert.equal(normal.status, 0, normal.stderr);
  assert.equal(strict.status, incomplete.length > 0 ? 2 : 0, strict.stderr);
  assert.equal(normal.report.total, source.controls.length);
  assert.equal(normal.report.implemented, byStatus('implemented').length);
  assert.equal(normal.report.pending, byStatus('pending').length);
  assert.equal(normal.report.in_progress, byStatus('in_progress').length);
  assert.equal(normal.report.incomplete, incomplete.length);
  assert.deepEqual(normal.report.pending_controls, byStatus('pending').map(({ id }) => id));
  assert.deepEqual(normal.report.in_progress_controls, byStatus('in_progress').map(({ id }) => id));
  assert.deepEqual(normal.report.incomplete_controls, incomplete.map(({ id }) => id));
  const { generated_at: normalGeneratedAt, ...normalReport } = normal.report;
  const { generated_at: strictGeneratedAt, ...strictReport } = strict.report;
  assert.deepEqual(strictReport, normalReport);
  assert.equal(readFileSync(registry, 'utf8'), original);
});
