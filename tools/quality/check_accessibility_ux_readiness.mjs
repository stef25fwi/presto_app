#!/usr/bin/env node
import fs from 'node:fs';

const path = 'quality/accessibility_ux_readiness.json';
const enforce = process.argv.includes('--enforce');
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

if (data.schema_version !== 1 || data.phase !== 13 || !Array.isArray(data.controls)) {
  throw new Error('Registre accessibilité/UX invalide.');
}

const allowed = new Set(['complete', 'pending', 'blocked']);
for (const control of data.controls) {
  if (!control.id || !control.title || !allowed.has(control.status) || !Array.isArray(control.evidence)) {
    throw new Error(`Contrôle invalide: ${JSON.stringify(control)}`);
  }
}

const pending = data.controls.filter((control) => control.status !== 'complete');
const report = {
  phase: data.phase,
  total: data.controls.length,
  complete: data.controls.length - pending.length,
  pending: pending.map((control) => control.id),
};

fs.mkdirSync('build/quality', { recursive: true });
fs.writeFileSync('build/quality/accessibility-ux-readiness-report.json', `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));

if (enforce && pending.length > 0) {
  process.exitCode = 1;
}
