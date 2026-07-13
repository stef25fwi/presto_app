#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

const registryPath = process.argv[2] ?? 'quality/production_readiness.json';
const enforce = process.argv.includes('--enforce');

function existsNonEmpty(filePath) {
  try {
    return fs.statSync(filePath).isFile() && fs.readFileSync(filePath).length > 0;
  } catch {
    return false;
  }
}

const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
const results = registry.phases.map((phase) => {
  const evidence = phase.requiredEvidence.map((file) => ({
    file,
    present: existsNonEmpty(path.normalize(file)),
  }));
  const present = evidence.filter((item) => item.present).length;
  return {
    phase: phase.phase,
    name: phase.name,
    present,
    required: evidence.length,
    ready: present === evidence.length,
    evidence,
  };
});

const ready = results.filter((result) => result.ready).length;
const report = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  readyPhases: ready,
  totalPhases: results.length,
  allReady: ready === results.length,
  phases: results,
};

fs.mkdirSync('quality_reports/production-readiness', { recursive: true });
fs.writeFileSync(
  'quality_reports/production-readiness/report.json',
  `${JSON.stringify(report, null, 2)}\n`,
);

console.log(`production readiness: ${ready}/${results.length} phases avec toutes leurs preuves`);
for (const result of results) {
  console.log(
    `phase ${result.phase}: ${result.ready ? 'READY' : 'INCOMPLETE'} (${result.present}/${result.required})`,
  );
  for (const item of result.evidence.filter((entry) => !entry.present)) {
    console.log(`  - manquant: ${item.file}`);
  }
}

if (enforce && !report.allReady) {
  console.error('Go-live refusé : les preuves requises des phases 8 à 16 sont incomplètes.');
  process.exitCode = 1;
}
