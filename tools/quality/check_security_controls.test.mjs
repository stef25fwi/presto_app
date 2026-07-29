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

test('un contrôle automatisé dérive son statut du code de sortie', async () => {
  const rootDir = await fixture([
    {
      id: 'automated-ok',
      kind: 'automated',
      required: true,
      status: 'pending',
      command: ['node', '-e', 'process.exit(0)'],
      evidence: 'proof.md',
    },
  ]);
  await fs.writeFile(path.join(rootDir, 'proof.md'), 'ok');
  const report = await evaluateSecurityControls({ rootDir });
  // Le fichier déclare "pending" : seule l'exécution fait foi.
  assert.equal(report.controls[0].status, 'verified');
  assert.equal(report.controls[0].commandResult, 'commande-reussie');
  assert.equal(report.ready, true);
});

test('un contrôle automatisé déclaré vérifié échoue si sa commande échoue', async () => {
  const rootDir = await fixture([
    {
      id: 'automated-ko',
      kind: 'automated',
      required: true,
      status: 'verified',
      command: ['node', '-e', 'process.exit(2)'],
      evidence: 'proof.md',
    },
  ]);
  await fs.writeFile(path.join(rootDir, 'proof.md'), 'ok');
  const report = await evaluateSecurityControls({ rootDir });
  assert.equal(report.controls[0].status, 'failed');
  assert.equal(report.ready, false);
  assert.match(report.failures[0], /automated-control-failed/);
});

test('un contrôle automatisé sans commande exploitable échoue', async () => {
  const rootDir = await fixture([
    {
      id: 'automated-no-command',
      kind: 'automated',
      required: true,
      evidence: 'proof.md',
    },
  ]);
  await fs.writeFile(path.join(rootDir, 'proof.md'), 'ok');
  const report = await evaluateSecurityControls({ rootDir });
  assert.equal(report.controls[0].commandResult, 'commande-invalide');
  assert.equal(report.ready, false);
});

test('runCommands:false neutralise les contrôles automatisés sans les valider', async () => {
  const rootDir = await fixture([
    {
      id: 'automated-skipped',
      kind: 'automated',
      required: true,
      status: 'verified',
      command: ['node', '-e', 'process.exit(2)'],
      evidence: 'proof.md',
    },
  ]);
  await fs.writeFile(path.join(rootDir, 'proof.md'), 'ok');
  const report = await evaluateSecurityControls({ rootDir, runCommands: false });
  assert.equal(report.controls[0].status, 'skipped');
  assert.equal(report.controls[0].complete, false);
  assert.deepEqual(report.failures, []);
});

test('refuse deux contrôles portant le même identifiant', async () => {
  const rootDir = await fixture([
    { id: 'doublon', kind: 'external-evidence', required: false, evidence: 'a.md' },
    { id: 'doublon', kind: 'external-evidence', required: false, evidence: 'a.md' },
  ]);
  const report = await evaluateSecurityControls({ rootDir });
  assert.equal(report.ready, false);
  assert.match(report.failures[0], /duplicate-or-missing-id:doublon/);
});
