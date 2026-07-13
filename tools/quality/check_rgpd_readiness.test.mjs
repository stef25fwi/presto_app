import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateRgpdReadiness } from './check_rgpd_readiness.mjs';

test('reports pending controls without failing inventory structure', () => {
  const report = evaluateRgpdReadiness({
    controls: [
      { id: 'privacy', title: 'Privacy', status: 'implemented', evidence: ['doc.md'] },
      { id: 'export', title: 'Export', status: 'pending', evidence: [] },
    ],
  });
  assert.equal(report.total, 2);
  assert.equal(report.implemented, 1);
  assert.equal(report.pending, 1);
  assert.equal(report.ready, false);
  assert.deepEqual(report.invalid, []);
});

test('requires evidence for every implemented control', () => {
  const report = evaluateRgpdReadiness({
    controls: [{ id: 'delete', title: 'Delete', status: 'implemented', evidence: [] }],
  });
  assert.deepEqual(report.missingEvidence, ['delete']);
  assert.equal(report.ready, false);
});

test('is ready only when every valid control is implemented with evidence', () => {
  const report = evaluateRgpdReadiness({
    controls: [
      { id: 'export', title: 'Export', status: 'implemented', evidence: ['export-test.json'] },
      { id: 'delete', title: 'Delete', status: 'implemented', evidence: ['delete-test.json'] },
    ],
  });
  assert.equal(report.ready, true);
  assert.equal(report.pending, 0);
});
