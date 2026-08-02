import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
const result = spawnSync(process.execPath, ['tools/quality/check_marketplace_readiness.mjs', '--enforce'], { encoding: 'utf8' });
assert.equal(result.status, 0, result.stderr || result.stdout);
assert.match(result.stdout, /Marketplace readiness: OK/);
console.log('check_marketplace_readiness.test: OK');
