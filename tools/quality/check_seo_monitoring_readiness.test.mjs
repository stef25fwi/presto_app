import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const result = spawnSync(
  process.execPath,
  ['tools/quality/check_seo_monitoring_readiness.mjs'],
  { encoding: 'utf8' },
);

assert.equal(result.status, 0, result.stderr || result.stdout);
assert.match(result.stdout, /SEO monitoring readiness: OK/);
console.log('check_seo_monitoring_readiness.test: OK');
