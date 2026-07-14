import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const data = JSON.parse(fs.readFileSync('quality/accessibility_ux_readiness.json', 'utf8'));

test('le registre cible bien la phase 13', () => {
  assert.equal(data.phase, 13);
  assert.equal(data.schema_version, 1);
});

test('chaque contrôle possède un identifiant unique et un statut valide', () => {
  const ids = data.controls.map((control) => control.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const control of data.controls) {
    assert.ok(['complete', 'pending', 'blocked'].includes(control.status));
    assert.ok(Array.isArray(control.evidence));
  }
});
