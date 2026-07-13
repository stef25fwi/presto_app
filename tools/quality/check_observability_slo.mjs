#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

export function evaluateObservability(register, root = process.cwd()) {
  const controls = Array.isArray(register.controls) ? register.controls : [];
  const results = controls.map((control) => {
    const evidence = Array.isArray(control.evidence) ? control.evidence : [];
    const missing = evidence.filter((entry) => !fs.existsSync(path.join(root, entry)));
    const valid = control.status !== 'implemented' || (evidence.length > 0 && missing.length === 0);
    return { id: control.id, status: control.status, valid, missing };
  });
  const pending = results.filter((item) => item.status !== 'implemented');
  const invalid = results.filter((item) => !item.valid);
  return {
    phase: 9,
    ready: pending.length === 0 && invalid.length === 0,
    implemented: results.length - pending.length,
    total: results.length,
    pending: pending.map((item) => item.id),
    invalid
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const register = JSON.parse(fs.readFileSync('quality/observability_slo.json', 'utf8'));
  const report = evaluateObservability(register);
  fs.mkdirSync('quality_reports/observability-slo', { recursive: true });
  fs.writeFileSync('quality_reports/observability-slo/report.json', `${JSON.stringify(report, null, 2)}\n`);
  console.log(`phase 9 observability: ${report.implemented}/${report.total}`);
  if (report.invalid.length > 0 || (process.argv.includes('--enforce') && !report.ready)) process.exitCode = 1;
}
