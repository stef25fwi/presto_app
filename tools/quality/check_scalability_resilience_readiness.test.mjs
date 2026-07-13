import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const registry = JSON.parse(await readFile('quality/scalability_resilience_readiness.json', 'utf8'));

test('phase 15 registry exposes required controls', () => {
  assert.equal(registry.phase, 15);
  const ids = new Set(registry.controls.map((control) => control.id));
  for (const required of [
    'load-test-1k',
    'load-test-10k',
    'load-test-50k',
    'firestore-cost-budget',
    'functions-cost-budget',
    'storage-cost-budget',
    'cost-alerting',
    'backup-restore-runbook',
    'timed-restore-exercise',
    'regional-resilience-strategy',
    'critical-dependency-register'
  ]) assert.ok(ids.has(required), `missing ${required}`);
});

test('verified controls declare evidence', () => {
  for (const control of registry.controls) {
    if (control.status === 'verified') assert.ok(control.evidence.length > 0);
  }
});
