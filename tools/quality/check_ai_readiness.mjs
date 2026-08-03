#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const registryPath = 'quality/ai-readiness.json';
const enforce = process.argv.includes('--enforce');
const data = JSON.parse(fs.readFileSync(registryPath, 'utf8'));

if (data.schemaVersion !== 1 || data.point !== 8 || data.name !== 'Fonctions IA') {
  throw new Error('Registre IA du point 8 invalide.');
}
if (!Array.isArray(data.controls) || data.controls.length === 0) {
  throw new Error('Le registre IA doit contenir des contrôles.');
}

const allowed = new Set(['verified', 'complete', 'in_progress', 'pending', 'blocked']);
const accepted = new Set(['verified', 'complete']);
const ids = new Set();
const missingEvidence = [];

for (const control of data.controls) {
  if (!control.id || !control.label || !allowed.has(control.status)) {
    throw new Error(`Contrôle IA invalide: ${JSON.stringify(control)}`);
  }
  if (ids.has(control.id)) {
    throw new Error(`Identifiant IA dupliqué: ${control.id}`);
  }
  ids.add(control.id);
  if (!Array.isArray(control.evidence) || control.evidence.length === 0) {
    throw new Error(`Le contrôle ${control.id} ne référence aucune preuve.`);
  }
  for (const evidencePath of control.evidence) {
    if (!fs.existsSync(evidencePath)) {
      missingEvidence.push({ control: control.id, path: evidencePath });
    }
  }
}

if (missingEvidence.length > 0) {
  throw new Error(
    `Preuves IA absentes: ${missingEvidence
      .map((item) => `${item.control}:${item.path}`)
      .join(', ')}`,
  );
}

const pending = data.controls.filter((control) => !accepted.has(control.status));
const verified = data.controls.filter((control) => accepted.has(control.status));
const registryComplete = accepted.has(data.status) && pending.length === 0;

if (accepted.has(data.status) !== (pending.length === 0)) {
  throw new Error(
    'Le statut global IA doit être verified/complete uniquement lorsque tous les contrôles le sont.',
  );
}

const report = {
  point: data.point,
  total: data.controls.length,
  verified: verified.length,
  pending: pending.map((control) => control.id),
  complete: registryComplete,
};

const outputPath = path.join('build', 'quality', 'ai-readiness-report.json');
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));

if (enforce && !registryComplete) {
  process.exitCode = 1;
}
