#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const repoRoot = path.resolve(import.meta.dirname, '..', '..');
const checker = path.join(repoRoot, 'tools', 'quality', 'check_ai_readiness.mjs');
const sourceRegistry = path.join(repoRoot, 'quality', 'ai-readiness.json');

function runInFixture(registry, args = []) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-readiness-'));
  fs.mkdirSync(path.join(temp, 'quality'), { recursive: true });
  fs.mkdirSync(path.join(temp, 'docs', 'evidence', 'ai'), { recursive: true });
  fs.mkdirSync(path.join(temp, 'docs', 'production'), { recursive: true });
  fs.mkdirSync(path.join(temp, 'functions', 'scripts'), { recursive: true });
  fs.mkdirSync(path.join(temp, 'functions', 'src'), { recursive: true });

  for (const control of registry.controls) {
    for (const evidence of control.evidence) {
      const target = path.join(temp, evidence);
      if (path.extname(target)) {
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.writeFileSync(target, 'preuve\n');
      } else {
        fs.mkdirSync(target, { recursive: true });
      }
    }
  }
  fs.writeFileSync(
    path.join(temp, 'quality', 'ai-readiness.json'),
    `${JSON.stringify(registry, null, 2)}\n`,
  );

  return spawnSync(process.execPath, [checker, ...args], {
    cwd: temp,
    encoding: 'utf8',
  });
}

const base = JSON.parse(fs.readFileSync(sourceRegistry, 'utf8'));

const partial = runInFixture(base);
assert.equal(partial.status, 0, partial.stderr);
assert.match(partial.stdout, /"complete": false/);

const partialEnforced = runInFixture(base, ['--enforce']);
assert.equal(partialEnforced.status, 1);

const completeRegistry = structuredClone(base);
completeRegistry.status = 'verified';
for (const control of completeRegistry.controls) control.status = 'verified';
const complete = runInFixture(completeRegistry, ['--enforce']);
assert.equal(complete.status, 0, complete.stderr);
assert.match(complete.stdout, /"complete": true/);

const inconsistent = structuredClone(base);
inconsistent.status = 'verified';
const inconsistentRun = runInFixture(inconsistent);
assert.notEqual(inconsistentRun.status, 0);
assert.match(inconsistentRun.stderr, /statut global IA/);

const duplicate = structuredClone(base);
duplicate.controls[1].id = duplicate.controls[0].id;
const duplicateRun = runInFixture(duplicate);
assert.notEqual(duplicateRun.status, 0);
assert.match(duplicateRun.stderr, /dupliqué/);

console.log('AI readiness checker tests passed.');
