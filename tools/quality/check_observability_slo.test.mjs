import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluateObservability } from './check_observability_slo.mjs';

test('signale les contrôles pending sans invalider les preuves existantes', () => {
  const report = evaluateObservability({ controls: [
    { id: 'a', status: 'pending', evidence: [] },
    { id: 'b', status: 'implemented', evidence: ['package.json'] }
  ] });
  assert.equal(report.ready, false);
  assert.deepEqual(report.pending, ['a']);
  assert.equal(report.invalid.length, 0);
});

test('refuse un contrôle implemented sans preuve disponible', () => {
  const report = evaluateObservability({ controls: [
    { id: 'missing', status: 'implemented', evidence: ['missing-file.txt'] }
  ] });
  assert.equal(report.ready, false);
  assert.equal(report.invalid.length, 1);
});

test('valide un registre intégralement prouvé', () => {
  const report = evaluateObservability({ controls: [
    { id: 'ok', status: 'implemented', evidence: ['package.json'] }
  ] });
  assert.equal(report.ready, true);
});
