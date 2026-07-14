import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, unlinkSync } from 'node:fs';

const report = 'mobile-readiness-report.json';
if (existsSync(report)) unlinkSync(report);

const result = spawnSync(process.execPath, ['tools/quality/check_mobile_readiness.mjs'], {
  encoding: 'utf8'
});
assert.equal(result.status, 0, result.stderr);
assert.equal(existsSync(report), true);

const strictResult = spawnSync(
  process.execPath,
  ['tools/quality/check_mobile_readiness.mjs', '--enforce'],
  { encoding: 'utf8' }
);
assert.equal(strictResult.status, 2);
console.log('mobile readiness checker: ok');
