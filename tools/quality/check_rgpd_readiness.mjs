#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';

export function evaluateRgpdReadiness(config) {
  const controls = Array.isArray(config?.controls) ? config.controls : [];
  const normalized = controls.map((control) => ({
    id: String(control?.id ?? ''),
    title: String(control?.title ?? ''),
    status: String(control?.status ?? 'pending'),
    evidence: Array.isArray(control?.evidence) ? control.evidence : [],
  }));

  const invalid = normalized.filter(
    (control) => !control.id || !['implemented', 'pending', 'blocked'].includes(control.status),
  );
  const implemented = normalized.filter((control) => control.status === 'implemented');
  const missingEvidence = implemented.filter((control) => control.evidence.length === 0);
  const pending = normalized.filter((control) => control.status !== 'implemented');

  return {
    phase: 10,
    total: normalized.length,
    implemented: implemented.length,
    pending: pending.length,
    invalid: invalid.map((control) => control.id || '<missing-id>'),
    missingEvidence: missingEvidence.map((control) => control.id),
    ready: normalized.length > 0 && invalid.length === 0 && pending.length === 0 && missingEvidence.length === 0,
    controls: normalized,
  };
}

async function main() {
  const enforce = process.argv.includes('--enforce');
  const root = process.cwd();
  const source = path.join(root, 'quality', 'rgpd_readiness.json');
  const reportDir = path.join(root, 'quality_reports', 'rgpd');
  const reportFile = path.join(reportDir, 'report.json');
  const config = JSON.parse(await fs.readFile(source, 'utf8'));
  const report = evaluateRgpdReadiness(config);

  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(reportFile, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`RGPD readiness: ${report.implemented}/${report.total} controls implemented.`);

  if (report.invalid.length > 0 || report.missingEvidence.length > 0 || (enforce && !report.ready)) {
    process.exitCode = 1;
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
