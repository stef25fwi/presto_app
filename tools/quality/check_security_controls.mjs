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

  const ids = new Set();
  for (const control of config.controls ?? []) {
    if (!control.id || ids.has(control.id)) {
      failures.push(`duplicate-or-missing-id:${control.id ?? 'unknown'}`);
      continue;
    }
    ids.add(control.id);

    const evidencePath = path.join(rootDir, control.evidence ?? '');
    let evidenceExists = false;
    try {
      const stat = await fs.stat(evidencePath);
      evidenceExists = stat.isFile();
    } catch {
      evidenceExists = false;
    }

    const complete = control.status === 'verified' && evidenceExists;
    controls.push({ ...control, evidenceExists, complete });

    if (control.required && control.kind === 'source-control' && !complete) {
      failures.push(`${control.id}:source-control-not-verifiable`);
    }
    if (enforce && control.required && !complete) {
      failures.push(`${control.id}:required-control-incomplete`);
    }
  }

  return {
    schemaVersion: config.schema_version,
    enforce,
    ready: failures.length === 0,
    total: controls.length,
    verified: controls.filter((control) => control.complete).length,
    pending: controls.filter((control) => !control.complete).length,
    failures,
    controls,
  };
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
  process.stdout.write(`${JSON.stringify(report)}\n`);
  if (!report.ready) process.exitCode = 2;
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
