import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const registryPath = path.join(root, 'quality/scalability_resilience_readiness.json');
const reportPath = path.join(root, 'build/quality/scalability-resilience-readiness-report.json');
const enforce = process.argv.includes('--enforce');
const registry = JSON.parse(await readFile(registryPath, 'utf8'));
const allowed = new Set(['verified', 'pending', 'blocked']);
const failures = [];

for (const control of registry.controls ?? []) {
  if (!control.id || !allowed.has(control.status)) {
    failures.push(`Contrôle invalide: ${JSON.stringify(control)}`);
    continue;
  }
  if (control.status === 'verified' && !(control.evidence?.length > 0)) {
    failures.push(`${control.id}: preuve requise pour un contrôle vérifié`);
  }
  for (const evidence of control.evidence ?? []) {
    try {
      await access(path.join(root, evidence));
    } catch {
      failures.push(`${control.id}: preuve introuvable ${evidence}`);
    }
  }
  if (enforce && control.status !== 'verified') failures.push(`${control.id}: statut ${control.status}`);
}

const report = {
  phase: registry.phase,
  generatedAt: new Date().toISOString(),
  enforce,
  totals: {
    controls: registry.controls?.length ?? 0,
    verified: registry.controls?.filter((item) => item.status === 'verified').length ?? 0,
    pending: registry.controls?.filter((item) => item.status === 'pending').length ?? 0,
    blocked: registry.controls?.filter((item) => item.status === 'blocked').length ?? 0
  },
  failures
};

await mkdir(path.dirname(reportPath), { recursive: true });
await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
if (failures.length > 0) process.exitCode = 1;
