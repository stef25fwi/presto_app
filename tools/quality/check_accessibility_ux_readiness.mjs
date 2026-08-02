#!/usr/bin/env node
import fs from 'node:fs';

const path = 'quality/accessibility_ux_readiness.json';
const enforce = process.argv.includes('--enforce');
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

if (![1, 2].includes(data.schema_version) || data.phase !== 13 || !Array.isArray(data.controls)) {
  throw new Error('Registre accessibilité/UX invalide.');
}

const allowed = new Set(['verified', 'complete', 'pending', 'blocked']);
const accepted = new Set(['verified', 'complete']);
const ids = new Set();

for (const control of data.controls) {
  if (
    !control.id ||
    !control.title ||
    !allowed.has(control.status) ||
    !Array.isArray(control.evidence)
  ) {
    throw new Error(`Contrôle invalide: ${JSON.stringify(control)}`);
  }
  if (ids.has(control.id)) {
    throw new Error(`Identifiant de contrôle dupliqué: ${control.id}`);
  }
  ids.add(control.id);
  if (accepted.has(control.status) && control.evidence.length === 0) {
    throw new Error(`Le contrôle ${control.id} est vérifié sans preuve.`);
  }
}

const pending = data.controls.filter((control) => !accepted.has(control.status));
const verified = data.controls.filter((control) => accepted.has(control.status));
const report = {
  phase: data.phase,
  total: data.controls.length,
  verified: verified.length,
  pending: pending.map((control) => control.id),
  complete: pending.length === 0,
};

fs.mkdirSync('build/quality', { recursive: true });
fs.writeFileSync(
  'build/quality/accessibility-ux-readiness-report.json',
  `${JSON.stringify(report, null, 2)}\n`,
);
console.log(JSON.stringify(report, null, 2));

if (enforce && pending.length > 0) {
  process.exitCode = 1;
}
