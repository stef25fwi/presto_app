#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

function parseArgs(argv) {
  const args = {
    roots: ['docs/menu_activite_statuts'],
    output: 'build/quality/parcours-fiches-review-schedule.json',
    today: new Date().toISOString().slice(0, 10),
    enforce: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--root') args.roots = [argv[++index]];
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

function validDate(value) {
  return /^\d{4}-\d{2}-\d{2}$/.test(String(value ?? ''));
}

export function reviewState(fiche, today) {
  const status = String(fiche.review_status ?? 'non_auditee');
  const reviewedAt = String(fiche.reviewed_at ?? '');
  const nextReviewAt = String(fiche.next_review_at ?? '');
  if (!nextReviewAt) {
    return {
      state: 'unscheduled',
      blocking: ['validee', 'publiee'].includes(status),
      reason: 'Aucune date de prochaine révision.',
    };
  }
  if (!validDate(nextReviewAt)) {
    return { state: 'invalid_date', blocking: true, reason: 'Date de prochaine révision invalide.' };
  }
  if (nextReviewAt < today) {
    return { state: 'overdue', blocking: ['validee', 'publiee'].includes(status), reason: `Révision échue depuis le ${nextReviewAt}.` };
  }
  if (reviewedAt && !validDate(reviewedAt)) {
    return { state: 'invalid_date', blocking: true, reason: 'Date de dernière révision invalide.' };
  }
  return { state: 'scheduled', blocking: false, reason: `Prochaine révision le ${nextReviewAt}.` };
}

export function buildReviewSchedule({ roots, today }) {
  const files = roots.flatMap(collectJsonFiles);
  const fiches = [];
  for (const file of files) {
    let raw;
    try {
      raw = JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (error) {
      fiches.push({ file, id: path.basename(file, '.json'), activity: '', reviewStatus: 'non_auditee', state: 'invalid_json', blocking: true, reason: error.message });
      continue;
    }
    const state = reviewState(raw, today);
    fiches.push({
      file,
      id: raw.id_fiche ?? raw.id ?? path.basename(file, '.json'),
      activity: raw.activite ?? '',
      reviewStatus: raw.review_status ?? 'non_auditee',
      reviewedAt: raw.reviewed_at ?? null,
      nextReviewAt: raw.next_review_at ?? null,
      reviewer: raw.reviewer ?? null,
      ...state,
    });
  }
  const byState = {};
  for (const fiche of fiches) byState[fiche.state] = (byState[fiche.state] ?? 0) + 1;
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    effectiveDate: today,
    totalFiles: fiches.length,
    blockingFiles: fiches.filter((item) => item.blocking).length,
    byState,
    fiches,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const report = buildReviewSchedule(args);
  fs.mkdirSync(path.dirname(args.output), { recursive: true });
  fs.writeFileSync(args.output, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`calendrier de révision: ${report.totalFiles} fiches, ${report.blockingFiles} blocages`);
  for (const [state, count] of Object.entries(report.byState)) console.log(`  ${state}: ${count}`);
  if (args.enforce && report.blockingFiles > 0) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
