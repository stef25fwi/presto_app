import assert from 'node:assert/strict';
import fs from 'node:fs';

const registry = JSON.parse(fs.readFileSync('quality/seo_acquisition_readiness.json', 'utf8'));

assert.equal(registry.phase, 14);
assert.ok(Array.isArray(registry.controls));
assert.ok(registry.controls.length >= 8);
assert.equal(new Set(registry.controls.map((control) => control.id)).size, registry.controls.length);
for (const control of registry.controls) {
  assert.ok(control.id);
  assert.ok(['complete', 'pending', 'not_applicable'].includes(control.status));
  assert.ok(control.evidence);
}

console.log('SEO acquisition readiness registry: OK');
