import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const registry = JSON.parse(await readFile('quality/production_go_live_readiness.json', 'utf8'));

test('phase 16 registry exposes required go-live controls', () => {
  assert.equal(registry.phase, 16);
  const ids = new Set(registry.controls.map((control) => control.id));
  for (const required of [
    'all-prior-phases-reviewed',
    'release-candidate-tag',
    'production-smoke-tests',
    'rollback-plan-tested',
    'incident-contacts-confirmed',
    'support-playbook-ready',
    'monitoring-dashboards-live',
    'legal-store-assets-approved',
    'go-no-go-decision-recorded',
    'post-launch-review-scheduled'
  ]) assert.ok(ids.has(required), `missing ${required}`);
});

test('verified controls declare evidence', () => {
  for (const control of registry.controls) {
    if (control.status === 'verified') assert.ok(control.evidence.length > 0);
  }
});
