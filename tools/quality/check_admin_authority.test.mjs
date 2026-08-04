#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

import {
  extractCallableBlocks,
  extractFunctionBody,
  resolveAppCheck,
  rolesFromRequireAnyRole,
} from './check_admin_authority.mjs';

const repoRoot = path.resolve(import.meta.dirname, '..', '..');
const checker = path.join(repoRoot, 'tools', 'quality', 'check_admin_authority.mjs');
const matrixPath = path.join(repoRoot, 'quality', 'admin-authority-matrix.json');

function copyInto(temp, relativePath) {
  const target = path.join(temp, relativePath);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(path.join(repoRoot, relativePath), target);
}

function runInFixture(matrix, mutate) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'admin-authority-'));
  copyInto(temp, 'firestore.rules');
  // Les sources copiées sont toujours celles du dépôt réel, indépendamment de
  // la matrice testée : c'est ce qui permet de vérifier la détection de dérive
  // quand une opération existante disparaît de la déclaration.
  for (const relativePath of sourceFiles) copyInto(temp, relativePath);
  fs.mkdirSync(path.join(temp, 'quality'), { recursive: true });
  fs.writeFileSync(
    path.join(temp, 'quality', 'admin-authority-matrix.json'),
    `${JSON.stringify(matrix, null, 2)}\n`,
  );
  if (mutate) mutate(temp);
  return spawnSync(process.execPath, [checker], { cwd: temp, encoding: 'utf8' });
}

const base = JSON.parse(fs.readFileSync(matrixPath, 'utf8'));
const sourceFiles = [
  ...new Set([
    ...base.operations.map((operation) => operation.file),
    ...base.guards.map((guard) => guard.file),
  ]),
];

// Le dépôt réel doit passer.
const real = spawnSync(process.execPath, [checker], { cwd: repoRoot, encoding: 'utf8' });
assert.equal(real.status, 0, real.stderr);
assert.match(real.stdout, /"complete": true/);

// Une opération déclarée avec des rôles trop larges est refusée.
const widened = structuredClone(base);
const target = widened.operations.find((item) => item.callable === 'applyUserRoleClaims');
target.roles = ['moderator'];
const widenedRun = runInFixture(widened);
assert.notEqual(widenedRun.status, 0);
assert.match(widenedRun.stderr, /applyUserRoleClaims: rôles/);

// Une opération d'administration retirée de la matrice est détectée comme dérive.
const dropped = structuredClone(base);
dropped.operations = dropped.operations.filter(
  (item) => item.callable !== 'adminBulkDeleteListings',
);
const droppedRun = runInFixture(dropped);
assert.notEqual(droppedRun.status, 0);
assert.match(droppedRun.stderr, /adminBulkDeleteListings: opération d'administration non déclarée/);

// App Check désactivé sans dérogation ouverte est refusé.
const waived = structuredClone(base);
const unblock = waived.operations.find((item) => item.callable === 'adminUnblockConversation');
delete unblock.appCheckWaiver;
const waivedRun = runInFixture(waived);
assert.notEqual(waivedRun.status, 0);
assert.match(waivedRun.stderr, /App Check désactivé sans dérogation/);

// Une mutation sans trace ni dérogation est refusée.
const unlogged = structuredClone(base);
const publish = unlogged.operations.find(
  (item) => item.callable === 'publishPaymentInfoAudioDraft',
);
publish.audit = 'none';
const unloggedRun = runInFixture(unlogged);
assert.notEqual(unloggedRun.status, 0);
assert.match(unloggedRun.stderr, /mutation d'administration non journalisée/);

// Les champs de rôle doivent rester protégés dans les règles Firestore.
const elevationRun = runInFixture(structuredClone(base), (temp) => {
  const rulesPath = path.join(temp, 'firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8').replace("        'roles',\n", '');
  fs.writeFileSync(rulesPath, rules);
});
assert.notEqual(elevationRun.status, 0);
assert.match(elevationRun.stderr, /champs de rôle inscriptibles côté client: roles/);

// Analyse statique : blocs, rôles, corps de fonction et App Check.
const sample = [
  'const SHARED = {',
  '  region: PROJECT_REGION,',
  '  enforceAppCheck: ENFORCE_APP_CHECK,',
  '};',
  '',
  'const RELAXED = {',
  '  ...SHARED,',
  '  enforceAppCheck: false,',
  '};',
  '',
  'function requireAdmin(request: {',
  '  auth?: { uid?: string } | null;',
  '}): { actorId: string } {',
  '  requireAnyRole(roles, ["admin", "superadmin"], "Admin access required");',
  '  return { actorId: "x" };',
  '}',
  '',
  'export const alpha = onCall(SHARED, async (request) => {',
  '  requireAdmin(request);',
  '});',
  '',
  'export const beta = onCall(RELAXED, async (request) => {',
  '  requireAnyRole(roles, ["moderator"], "Moderator required");',
  '});',
  '',
].join('\n');

const blocks = extractCallableBlocks(sample);
assert.deepEqual([...blocks.keys()], ['alpha', 'beta']);
assert.equal(resolveAppCheck(sample, blocks.get('alpha')), 'enforced');
// La désactivation portée par une constante dérivée reste visible.
assert.equal(resolveAppCheck(sample, blocks.get('beta')), 'disabled');
assert.deepEqual(rolesFromRequireAnyRole(blocks.get('beta')), ['moderator']);

// Le corps est bien celui de la fonction, pas le type des paramètres ni celui
// du retour — c'est la confusion qui masquerait une garde absente.
const body = extractFunctionBody(sample, 'requireAdmin');
assert.ok(body.includes('requireAnyRole'));
assert.deepEqual(rolesFromRequireAnyRole(body), ['admin', 'superadmin']);

console.log('Admin authority checker tests passed.');
