import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const script = path.resolve('tools/quality/check_stripe_readiness.mjs');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'stripe-readiness-'));
fs.mkdirSync(path.join(root, 'quality'), {recursive: true});
fs.mkdirSync(path.join(root, 'functions', 'src'), {recursive: true});

const base = {
  schemaVersion: 1,
  phase: 11,
  status: 'in_progress',
  controls: [
    {id: 'webhook', required: true, status: 'implemented', evidence: ['functions/src']},
    {id: 'e2e', required: true, status: 'pending', evidence: []}
  ]
};

fs.writeFileSync(path.join(root, 'quality', 'stripe-readiness.json'), JSON.stringify(base));
let result = spawnSync(process.execPath, [script], {cwd: root, encoding: 'utf8'});
assert.equal(result.status, 0, result.stderr);

result = spawnSync(process.execPath, [script, '--enforce'], {cwd: root, encoding: 'utf8'});
assert.notEqual(result.status, 0);
assert.match(result.stderr, /contrôle requis non implémenté/);

base.controls[1] = {id: 'e2e', required: true, status: 'implemented', evidence: ['functions/src']};
fs.writeFileSync(path.join(root, 'quality', 'stripe-readiness.json'), JSON.stringify(base));
result = spawnSync(process.execPath, [script, '--enforce'], {cwd: root, encoding: 'utf8'});
assert.equal(result.status, 0, result.stderr);

console.log('Stripe readiness tests: OK');
