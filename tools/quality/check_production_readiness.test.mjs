import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const script = path.resolve('tools/quality/check_production_readiness.mjs');

function runFixture({ present = false, enforce = false }) {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'presto-readiness-'));
  fs.mkdirSync(path.join(cwd, 'quality'), { recursive: true });
  const evidence = 'docs/evidence.md';
  fs.writeFileSync(
    path.join(cwd, 'quality/production_readiness.json'),
    JSON.stringify({
      schemaVersion: 1,
      phases: [{ phase: 16, name: 'Go-live', requiredEvidence: [evidence] }],
    }),
  );
  if (present) {
    fs.mkdirSync(path.join(cwd, 'docs'), { recursive: true });
    fs.writeFileSync(path.join(cwd, evidence), '# preuve\n');
  }
  return spawnSync(
    process.execPath,
    [script, 'quality/production_readiness.json', ...(enforce ? ['--enforce'] : [])],
    { cwd, encoding: 'utf8' },
  );
}

test('produit un rapport sans bloquer en mode inventaire', () => {
  const result = runFixture({ present: false, enforce: false });
  assert.equal(result.status, 0);
  assert.match(result.stdout, /0\/1 phases/);
});

test('bloque le go-live lorsque les preuves manquent', () => {
  const result = runFixture({ present: false, enforce: true });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Go-live refusé/);
});

test('valide une phase lorsque toutes les preuves sont présentes', () => {
  const result = runFixture({ present: true, enforce: true });
  assert.equal(result.status, 0);
  assert.match(result.stdout, /phase 16: READY/);
});
