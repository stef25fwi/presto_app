#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';

const args = new Set(process.argv.slice(2));
const enforce = args.has('--enforce');
const source = JSON.parse(readFileSync('quality/mobile_readiness.json', 'utf8'));
const allowed = new Set(['implemented', 'pending', 'not_applicable']);
const invalid = source.controls.filter((control) => !allowed.has(control.status));
if (invalid.length > 0) {
  console.error(`Statuts invalides: ${invalid.map((control) => control.id).join(', ')}`);
  process.exit(1);
}
const implemented = source.controls.filter((control) => control.status === 'implemented');
const pending = source.controls.filter((control) => control.status === 'pending');
const report = {
  phase: source.phase,
  generated_at: new Date().toISOString(),
  total: source.controls.length,
  implemented: implemented.length,
  pending: pending.length,
  completion_percent: Math.round((implemented.length / source.controls.length) * 100),
  pending_controls: pending.map((control) => control.id)
};
writeFileSync('mobile-readiness-report.json', `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
if (enforce && pending.length > 0) process.exit(2);
