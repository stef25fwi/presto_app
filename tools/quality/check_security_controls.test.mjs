import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { evaluateSecurityControls } from './check_security_controls.mjs';

async function fixture(controls) {
  const rootDir = await fs.mkdtemp(path.join(os.tmpdir(), 'security-controls-'));
  await fs.mkdir(path.join(rootDir, 'quality'), { recursive: true });
  await fs.writeFile(
    path.join(rootDir, 'quality/security-controls.json'),
    JSON.stringify({ schema_version: 1, controls }),
  );
  return rootDir;
}

test('accepte un contrôle source vérifié avec preuve existante', async () => {
  const rootDir = await fixture([
    {
      id: 'source-ok',
      kind: 'source-control',
      required: true,
      status: 'verified',
      evidence: 'proof.txt',
    },
  ]);
  await fs.writeFile(path.join(rootDir, 'proof.txt'), 'ok');
  const report = await evaluateSecurityControls({ rootDir });
  assert.equal(report.ready, true);
  assert.equal(report.verified, 1);
});

test('refuse un contrôle source dont la preuve manque', async () => {
  const rootDir = await fixture([
    {
      id: 'source-missing',
      kind: 'source-control',
      required: true,
      status: 'verified',
      evidence: 'missing.txt',
    },
  ]);
  const report = await evaluateSecurityControls({ rootDir });
  assert.equal(report.ready, false);
  assert.match(report.failures[0], /source-control-not-verifiable/);
});

test('le mode enforce refuse une preuve externe encore en attente', async () => {
  const rootDir = await fixture([
    {
      id: 'external-pending',
      kind: 'external-evidence',
      required: true,
      status: 'pending',
      evidence: 'external.md',
    },
  ]);
  const report = await evaluateSecurityControls({ rootDir, enforce: true });
  assert.equal(report.ready, false);
  assert.match(report.failures[0], /required-control-incomplete/);
});
