#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

import { auditFiche } from './check_parcours_fiches.mjs';
import { reviewState } from './check_parcours_review_schedule.mjs';

const requiredHumanChecks = [
  'coherence_metier',
  'chronologie',
  'personnalisation',
  'fiabilite',
  'controle_pdf',
];

function parseArgs(argv) {
  const args = {
    root: 'docs/menu_activite_statuts',
    manifest: 'quality/parcours_fiches_publication_manifest.json',
    rules: 'quality/parcours_fiches_audit_rules.json',
    output: 'build/quality/parcours-fiches-publication-gate.json',
    today: new Date().toISOString().slice(0, 10),
    enforce: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--root') args.root = argv[++index];
    else if (value === '--manifest') args.manifest = argv[++index];
    else if (value === '--rules') args.rules = argv[++index];
    else if (value === '--output') args.output = argv[++index];
    else if (value === '--today') args.today = argv[++index];
    else if (value === '--enforce') args.enforce = true;
  }
  return args;
}

function collectJsonFiles(root) {
  if (!fs.existsSync(root)) return [];
  const files = [];
  const stack = [root];
  while (stack.length > 0) {
    const current = stack.pop();
    const stat = fs.statSync(current);
    if (stat.isDirectory()) {
      for (const child of fs.readdirSync(current)) stack.push(path.join(current, child));
    } else if (current.endsWith('.json') && current.includes(`${path.sep}json${path.sep}`)) {
      files.push(current);
    }
  }
  return files.sort();
}

function humanValidationReasons(fiche) {
  const validation = fiche.human_validation;
  if (!validation || typeof validation !== 'object') {
    return ['La validation humaine structurée est absente.'];
  }

  const reasons = [];
  for (const check of requiredHumanChecks) {
    if (validation[check] !== true) {
      reasons.push(`Validation humaine non confirmée : ${check}.`);
    }
  }
  if (!validation.approved_by) {
    reasons.push('Le validateur final n’est pas renseigné.');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(validation.approved_at ?? ''))) {
    reasons.push('La date de validation finale est absente ou invalide.');
  }
  return reasons;
}

export function buildPublicationGate({ root, manifestPath, rulesPath, today }) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const rules = JSON.parse(fs.readFileSync(rulesPath, 'utf8'));
  const byId = new Map();

  for (const file of collectJsonFiles(root)) {
    const fiche = JSON.parse(fs.readFileSync(file, 'utf8'));
    const id = fiche.id_fiche ?? fiche.id ?? path.basename(file, '.json');
    byId.set(id, { file, fiche });
  }

  const requested = (manifest.published ?? []).map((entry) =>
    typeof entry === 'string' ? entry : entry.id,
  );
  const results = [];

  for (const id of requested) {
    const found = byId.get(id);
    if (!found) {
      results.push({
        id,
        allowed: false,
        reasons: ['Fiche introuvable dans le catalogue audité.'],
      });
      continue;
    }

    const audit = auditFiche(found.fiche, rules, found.file);
    const calendar = reviewState(found.fiche, today);
    const reasons = [];
    if (!['validee', 'publiee'].includes(found.fiche.review_status)) {
      reasons.push('Le statut doit être validee ou publiee.');
    }
    if ((audit.counts.blocker ?? 0) > 0 || (audit.counts.error ?? 0) > 0) {
      reasons.push('L’audit contient encore un blocage ou une erreur.');
    }
    if (calendar.state !== 'scheduled') {
      reasons.push(`Calendrier de révision non conforme : ${calendar.reason}`);
    }
    if (!found.fiche.reviewer) reasons.push('Le relecteur humain n’est pas renseigné.');
    reasons.push(...humanValidationReasons(found.fiche));

    results.push({
      id,
      file: found.file,
      activity: found.fiche.activite ?? '',
      reviewStatus: found.fiche.review_status ?? 'non_auditee',
      auditCounts: audit.counts,
      reviewCalendarState: calendar.state,
      humanValidation: found.fiche.human_validation ?? null,
      allowed: reasons.length === 0,
      reasons,
    });
  }

  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    effectiveDate: today,
    requested: requested.length,
    allowed: results.filter((item) => item.allowed).length,
    rejected: results.filter((item) => !item.allowed).length,
    allAllowed: results.every((item) => item.allowed),
    results,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const report = buildPublicationGate({
    root: args.root,
    manifestPath: args.manifest,
    rulesPath: args.rules,
    today: args.today,
  });
  fs.mkdirSync(path.dirname(args.output), { recursive: true });
  fs.writeFileSync(args.output, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`publication fiches: ${report.allowed}/${report.requested} autorisées, ${report.rejected} refusées`);
  for (const result of report.results.filter((item) => !item.allowed)) {
    console.log(`  ${result.id}: ${result.reasons.join(' ')}`);
  }
  if (args.enforce && !report.allAllowed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
