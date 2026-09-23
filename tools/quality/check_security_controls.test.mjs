import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { evaluateSecurityControls, formatSecuritySummary } from './check_security_controls.mjs';

const runFile = promisify(execFile);
const script = fileURLToPath(new URL('./check_security_controls.mjs', import.meta.url));

async function fixture(t, controls) {
  const rootDir = await fs.mkdtemp(path.join(os.tmpdir(), 'security-controls-'));
  t.after(() => fs.rm(rootDir, { recursive: true, force: true }));
  await fs.mkdir(path.join(rootDir, 'quality'), { recursive: true });
  await fs.writeFile(
    path.join(rootDir, 'quality/security-controls.json'),
    JSON.stringify({ schema_version: 1, controls }),
  );
  return rootDir;
}

test('accepte un contrôle source vérifié avec preuve existante', async (t) => {
  const rootDir = await fixture(t, [
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
  assert.equal(report.inventoryValid, true);
  assert.equal(report.passed, true);
  assert.deepEqual(report.blockingControls, []);
  assert.equal(report.verified, 1);
});

test('refuse un contrôle source dont la preuve manque', async (t) => {
  const rootDir = await fixture(t, [
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
  assert.equal(report.inventoryValid, false);
  assert.equal(report.passed, false);
  assert.match(report.failures[0], /source-control-not-verifiable/);
});

test('le mode enforce refuse une preuve externe encore en attente', async (t) => {
  const rootDir = await fixture(t, [
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
  assert.equal(report.inventoryValid, true);
  assert.equal(report.passed, false);
  assert.match(report.failures[0], /required-control-incomplete/);
});

const externalControl = {
  id: 'external-proof',
  kind: 'external-evidence',
  required: true,
  status: 'pending',
  evidence: 'proof.md',
};

test('un inventaire réussi ne déclare pas prête une preuve obligatoire en attente', async (t) => {
  const rootDir = await fixture(t, [externalControl]);
  await fs.writeFile(path.join(rootDir, 'proof.md'), 'Revue partielle');
  const inventory = await evaluateSecurityControls({ rootDir });
  const strict = await evaluateSecurityControls({ rootDir, enforce: true });
  assert.equal(inventory.inventoryValid, true);
  assert.equal(inventory.passed, true);
  assert.equal(inventory.ready, false);
  assert.equal(strict.ready, inventory.ready);
  assert.equal(strict.passed, false);
  assert.deepEqual(inventory.blockingControls, [{
    id: externalControl.id, reasons: ['status-not-verified'],
  }]);
  assert.match(formatSecuritySummary(inventory), /\*\*NOT READY\*\*/);
  assert.match(formatSecuritySummary(inventory), /external-proof: status-not-verified/);
});

for (const proof of ['missing', 'empty', 'whitespace', 'directory', 'symlink']) {
  test(`verified sans preuve exploitable reste bloquant : ${proof}`, async (t) => {
    const rootDir = await fixture(t, [{ ...externalControl, status: 'verified' }]);
    const proofPath = path.join(rootDir, 'proof.md');
    if (proof === 'empty') await fs.writeFile(proofPath, '');
    if (proof === 'whitespace') await fs.writeFile(proofPath, ' \n\t');
    if (proof === 'directory') await fs.mkdir(proofPath);
    if (proof === 'symlink') {
      await fs.writeFile(path.join(rootDir, 'target.md'), 'proof');
      await fs.symlink(path.join(rootDir, 'target.md'), proofPath);
    }
    for (const enforce of [false, true]) {
      const report = await evaluateSecurityControls({ rootDir, enforce });
      assert.equal(report.ready, false);
      assert.equal(report.passed, !enforce);
      assert.equal(report.verified, 0);
      assert.equal(report.pending, 1);
      assert.equal(report.blockingControls.length, 1);
    }
  });
}

test('une preuve externe documentée permet les deux modes', async (t) => {
  const rootDir = await fixture(t, [{ ...externalControl, status: 'verified' }]);
  await fs.writeFile(path.join(rootDir, 'proof.md'), 'Revue documentée');
  for (const enforce of [false, true]) {
    const report = await evaluateSecurityControls({ rootDir, enforce });
    assert.equal(report.ready, true);
    assert.equal(report.passed, true);
    assert.match(formatSecuritySummary(report), /\*\*READY\*\*/);
  }
});

test('une preuve derrière un répertoire symbolique ne valide pas le contrôle', async (t) => {
  const rootDir = await fixture(t, [{
    ...externalControl, status: 'verified', evidence: 'linked/proof.md',
  }]);
  await fs.mkdir(path.join(rootDir, 'actual'));
  await fs.writeFile(path.join(rootDir, 'actual/proof.md'), 'proof');
  await fs.symlink(path.join(rootDir, 'actual'), path.join(rootDir, 'linked'));
  const report = await evaluateSecurityControls({ rootDir });
  assert.equal(report.ready, false);
  assert.equal(report.controls[0].evidenceExists, false);
});

test('un contrôle facultatif incomplet ne bloque pas les contrôles obligatoires', async (t) => {
  const rootDir = await fixture(t, [
    { ...externalControl, status: 'verified' },
    { ...externalControl, id: 'optional', required: false },
  ]);
  await fs.writeFile(path.join(rootDir, 'proof.md'), 'Revue documentée');
  const report = await evaluateSecurityControls({ rootDir, enforce: true });
  assert.equal(report.ready, true);
  assert.equal(report.passed, true);
  assert.equal(report.pending, 1);
  assert.deepEqual(report.blockingControls, []);
});

for (const [label, controls] of [
  ['registre vide', []],
  ['liste manquante', undefined],
  ['liste invalide', {}],
  ['entrée nulle', [null]],
  ['identifiant manquant', [{ ...externalControl, id: '' }]],
  ['doublon', [externalControl, externalControl]],
  ['type inconnu', [{ ...externalControl, kind: 'unknown' }]],
  ['statut inconnu', [{ ...externalControl, status: 'approved' }]],
  ['required non booléen', [{ ...externalControl, required: 'false' }]],
  ['chemin absent', [{ ...externalControl, evidence: undefined }]],
  ['chemin hors dépôt', [{ ...externalControl, evidence: '../proof.md' }]],
]) {
  test(`un registre invalide échoue même en inventaire : ${label}`, async (t) => {
    const rootDir = await fixture(t, controls);
    const report = await evaluateSecurityControls({ rootDir });
    assert.equal(report.inventoryValid, false);
    assert.equal(report.ready, false);
    assert.equal(report.passed, false);
    assert.ok(report.failures.length > 0);
  });
}

test('une version de schéma inconnue échoue', async (t) => {
  const rootDir = await fixture(t, [externalControl]);
  await fs.writeFile(path.join(rootDir, 'quality/security-controls.json'),
    JSON.stringify({ schema_version: 999, controls: [externalControl] }));
  const report = await evaluateSecurityControls({ rootDir });
  assert.equal(report.passed, false);
  assert.equal(report.ready, false);
  assert.ok(report.failures.includes('unsupported-schema-version'));
});

test('CLI : inventaire exit 0, strict exit 2, mêmes blocages et rapports conservés', async (t) => {
  const rootDir = await fixture(t, [externalControl]);
  const summaryPath = path.join(rootDir, 'summary.md');
  const options = { cwd: rootDir, env: { ...process.env, GITHUB_STEP_SUMMARY: summaryPath } };
  const inventory = await runFile(process.execPath, [script], options);
  const inventoryReport = JSON.parse(inventory.stdout);
  assert.equal(inventoryReport.ready, false);
  assert.equal(inventoryReport.passed, true);
  assert.match(inventory.stderr, /NOT READY/);
  await assert.rejects(runFile(process.execPath, [script, '--enforce'], options), (error) => {
    assert.equal(error.code, 2);
    const report = JSON.parse(error.stdout);
    assert.equal(report.ready, false);
    assert.equal(report.passed, false);
    assert.deepEqual(report.blockingControls, inventoryReport.blockingControls);
    return true;
  });
  const persisted = JSON.parse(await fs.readFile(
    path.join(rootDir, 'quality_reports/security/security-controls.json'), 'utf8'));
  assert.equal(persisted.enforce, true);
  assert.equal(persisted.passed, false);
  assert.match(await fs.readFile(summaryPath, 'utf8'), /NOT READY/);
  assert.match(await fs.readFile(
    path.join(rootDir, 'quality_reports/security/security-controls.md'), 'utf8'), /strict readiness gate/);
});

test('CLI : registre invalide échoue en inventaire', async (t) => {
  const rootDir = await fixture(t, []);
  await assert.rejects(runFile(process.execPath, [script], {
    cwd: rootDir, env: { ...process.env, GITHUB_STEP_SUMMARY: '' },
  }), (error) => {
    assert.equal(error.code, 2);
    assert.equal(JSON.parse(error.stdout).passed, false);
    return true;
  });
});
