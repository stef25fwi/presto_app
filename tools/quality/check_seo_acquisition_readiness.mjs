import fs from 'node:fs';
import path from 'node:path';

const enforce = process.argv.includes('--enforce');
const root = process.cwd();
const source = path.join(root, 'quality', 'seo_acquisition_readiness.json');
const reportPath = path.join(root, 'build', 'quality', 'seo-acquisition-readiness-report.json');

const registry = JSON.parse(fs.readFileSync(source, 'utf8'));
const allowed = new Set(['complete', 'pending', 'not_applicable']);
const invalid = registry.controls.filter((control) => !allowed.has(control.status));
const pending = registry.controls.filter((control) => control.status === 'pending');
const complete = registry.controls.filter((control) => control.status === 'complete');

const report = {
  phase: registry.phase,
  name: registry.name,
  generatedAt: new Date().toISOString(),
  summary: {
    total: registry.controls.length,
    complete: complete.length,
    pending: pending.length,
    invalid: invalid.length
  },
  controls: registry.controls
};

fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

if (invalid.length > 0) {
  console.error(`Statuts invalides: ${invalid.map((item) => item.id).join(', ')}`);
  process.exit(1);
}

console.log(`Phase 14: ${complete.length}/${registry.controls.length} contrôles complets, ${pending.length} en attente.`);
if (enforce && pending.length > 0) process.exit(1);
