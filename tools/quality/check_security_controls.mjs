#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export async function evaluateSecurityControls({
  rootDir = process.cwd(),
  enforce = false,
} = {}) {
  const configPath = path.join(rootDir, 'quality/security-controls.json');
  const config = JSON.parse(await fs.readFile(configPath, 'utf8'));
  const failures = [];
  const controls = [];
  const blockingControls = [];

  if (config?.schema_version !== 1) failures.push('unsupported-schema-version');
  const entries = Array.isArray(config?.controls) ? config.controls : [];
  if (entries.length === 0) failures.push('missing-or-empty-controls');

  const ids = new Set();
  for (const control of entries) {
    if (typeof control?.id !== 'string' || !control.id.trim() || ids.has(control.id)) {
      failures.push(`duplicate-or-missing-id:${control?.id ?? 'unknown'}`);
      continue;
    }
    ids.add(control.id);
    if (!['source-control', 'external-evidence'].includes(control.kind)) {
      failures.push(`${control.id}:invalid-kind`);
    }
    if (!['verified', 'pending'].includes(control.status)) {
      failures.push(`${control.id}:invalid-status`);
    }
    if (typeof control.required !== 'boolean') {
      failures.push(`${control.id}:invalid-required`);
    }

    const evidencePath = typeof control.evidence === 'string'
      ? path.resolve(rootDir, control.evidence)
      : rootDir;
    const relativeEvidence = path.relative(path.resolve(rootDir), evidencePath);
    const evidenceWithinRoot = relativeEvidence !== '' &&
      relativeEvidence !== '..' &&
      !relativeEvidence.startsWith(`..${path.sep}`) &&
      !path.isAbsolute(relativeEvidence);
    if (!evidenceWithinRoot) failures.push(`${control.id}:invalid-evidence-path`);
    let evidenceExists = false;
    let evidenceNonEmpty = false;
    try {
      if (evidenceWithinRoot) {
        const stat = await fs.lstat(evidencePath);
        // A symlink alone is not an auditable, repository-owned proof.
        evidenceExists = stat.isFile() &&
          await fs.realpath(evidencePath) ===
            path.join(await fs.realpath(rootDir), relativeEvidence);
        evidenceNonEmpty = evidenceExists &&
          (await fs.readFile(evidencePath, 'utf8')).trim().length > 0;
      }
    } catch {
      evidenceExists = false;
    }

    const incompleteReasons = [];
    if (control.status !== 'verified') incompleteReasons.push('status-not-verified');
    if (!evidenceExists) incompleteReasons.push('evidence-missing');
    else if (!evidenceNonEmpty) incompleteReasons.push('evidence-empty');
    const complete = incompleteReasons.length === 0;
    controls.push({ ...control, evidenceExists, evidenceNonEmpty, complete, incompleteReasons });

    if (control.required && control.kind === 'source-control' && !complete) {
      failures.push(`${control.id}:source-control-not-verifiable`);
    }
    if (control.required && !complete) {
      blockingControls.push({ id: control.id, reasons: incompleteReasons });
    }
  }

  // Readiness is independent of the command's enforcement/exit policy.
  const inventoryValid = failures.length === 0;
  const ready = inventoryValid && blockingControls.length === 0;
  if (enforce) {
    failures.push(...blockingControls.map(({ id }) => `${id}:required-control-incomplete`));
  }

  return {
    schemaVersion: config?.schema_version,
    enforce,
    inventoryValid,
    ready,
    passed: inventoryValid && (!enforce || ready),
    blockingControls,
    total: controls.length,
    verified: controls.filter((control) => control.complete).length,
    pending: controls.filter((control) => !control.complete).length,
    failures,
    controls,
  };
}

export function formatSecuritySummary(report) {
  const lines = [
    '## Security controls',
    '',
    `- Mode: ${report.enforce ? 'strict readiness gate' : 'inventory only (not a go-live approval)'}`,
    `- Inventory valid: ${report.inventoryValid ? 'yes' : 'no'}`,
    `- Required controls ready: **${report.ready ? 'READY' : 'NOT READY'}**`,
    `- Documented controls: ${report.verified}/${report.total}`,
    '',
    'This checks declared statuses and non-empty evidence files, not live production settings or evidence freshness.',
  ];
  if (report.blockingControls.length) {
    lines.push('', '### Incomplete required controls', '');
    for (const { id, reasons } of report.blockingControls) {
      lines.push(`- ${id}: ${reasons.join(', ')}`);
    }
  }
  if (report.failures.length) {
    lines.push('', '### Validation failures', '', ...report.failures.map((failure) => `- ${failure}`));
  }
  return `${lines.join('\n')}\n`;
}

async function main() {
  const enforce = process.argv.includes('--enforce');
  const report = await evaluateSecurityControls({ enforce });
  const outputDir = path.join(process.cwd(), 'quality_reports/security');
  await fs.mkdir(outputDir, { recursive: true });
  await fs.writeFile(
    path.join(outputDir, 'security-controls.json'),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  const summary = formatSecuritySummary(report);
  await fs.writeFile(path.join(outputDir, 'security-controls.md'), summary);
  if (process.env.GITHUB_STEP_SUMMARY) {
    await fs.appendFile(process.env.GITHUB_STEP_SUMMARY, summary);
  }
  process.stdout.write(`${JSON.stringify(report)}\n`);
  if (!report.ready) {
    console.error('Security controls NOT READY. An inventory success is not a go-live approval.');
  }
  if (!report.passed) process.exitCode = 2;
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
