import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const data = JSON.parse(
  fs.readFileSync('quality/accessibility_ux_readiness.json', 'utf8'),
);

const accepted = new Set(['verified', 'complete']);

test('le registre cible bien la phase 13', () => {
  assert.equal(data.phase, 13);
  assert.ok([1, 2].includes(data.schema_version));
});

test('chaque contrôle possède un identifiant unique et un statut valide', () => {
  const ids = data.controls.map((control) => control.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const control of data.controls) {
    assert.ok(
      ['verified', 'complete', 'pending', 'blocked'].includes(control.status),
    );
    assert.ok(Array.isArray(control.evidence));
  }
});

test('un contrôle vérifié possède au moins une preuve existante', () => {
  for (const control of data.controls.filter((item) => accepted.has(item.status))) {
    assert.ok(
      control.evidence.length > 0,
      `${control.id} doit référencer une preuve`,
    );
    for (const evidence of control.evidence) {
      assert.ok(
        fs.existsSync(evidence),
        `${control.id} référence une preuve absente: ${evidence}`,
      );
    }
  }
});

test('la phase reste ouverte tant que les huit contrôles ne sont pas vérifiés', () => {
  const pending = data.controls.filter((control) => !accepted.has(control.status));
  assert.ok(pending.length > 0);
  assert.equal(data.status, 'in_progress');
});
