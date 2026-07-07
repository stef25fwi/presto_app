import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

function usage() {
  console.log(
    'Usage: node scripts/audit_parcours_fiches_pack.mjs --zip <pack.zip> [--out <report.md>]'
  );
}

function readArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    const next = argv[index + 1];
    if (current === '--zip') {
      args.zip = next;
      index += 1;
    } else if (current === '--out') {
      args.out = next;
      index += 1;
    } else if (current === '--help' || current === '-h') {
      usage();
      process.exit(0);
    }
  }
  if (!args.zip) {
    usage();
    throw new Error('Argument requis manquant: --zip');
  }
  return args;
}

function extractPack(zipPath) {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'audit-parcours-'));
  execFileSync('unzip', ['-oq', zipPath, '-d', tempDir], { stdio: 'inherit' });
  const jsonDir = findDirContaining(tempDir, 'json');
  if (!jsonDir) {
    throw new Error('Dossier json introuvable dans le pack');
  }
  return jsonDir;
}

function findDirContaining(root, targetName) {
  const entries = fs.readdirSync(root, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(root, entry.name);
    if (!entry.isDirectory()) {
      continue;
    }
    if (entry.name === targetName) {
      return fullPath;
    }
    const nested = findDirContaining(fullPath, targetName);
    if (nested) {
      return nested;
    }
  }
  return null;
}

function loadFiches(jsonDir) {
  return fs
    .readdirSync(jsonDir)
    .filter((entry) => entry.endsWith('.json'))
    .sort()
    .map((entry) => ({
      file: entry,
      data: JSON.parse(fs.readFileSync(path.join(jsonDir, entry), 'utf8')),
    }));
}

function findIssues(fiches) {
  const issues = [];
  for (const { file, data } of fiches) {
    const activity = data.activite?.toLowerCase() ?? '';
    const category = data.categorie?.toLowerCase() ?? '';
    const aggregate = [
      data.activite,
      data.categorie,
      data.famille,
      data.type_activite,
      data.qualification_regles,
    ]
      .join(' | ')
      .toLowerCase();

    if (
      activity.includes('informatique') &&
      !activity.includes('initiation') &&
      category !== 'cours & soutien' &&
      (aggregate.includes('enseignement') || aggregate.includes('scolaire'))
    ) {
      issues.push({
        severity: 'high',
        file,
        activity: data.activite,
        reason:
          'L’activité informatique est décrite avec un cadrage enseignement/soutien scolaire, probablement issu d’un mauvais template.',
      });
    }

    if (
      data.activite?.toLowerCase().includes('réseaux sociaux') &&
      (aggregate.includes('acaced') ||
        aggregate.includes('animaux') ||
        aggregate.includes('coaching sportif'))
    ) {
      issues.push({
        severity: 'medium',
        file,
        activity: data.activite,
        reason:
          'La fiche mélange des garde-fous d’autres métiers (animaux, coaching sportif), ce qui rend le texte trop générique pour une activité marketing/contenu.',
      });
    }

    if (
      data.activite?.toLowerCase().includes('coaching') &&
      aggregate.includes('acaced')
    ) {
      issues.push({
        severity: 'medium',
        file,
        activity: data.activite,
        reason:
          'La fiche coaching reprend des contraintes liées aux animaux, signe probable d’un collage de modèle trop large.',
      });
    }
  }
  return issues;
}

function renderReport({ zip, fiches, issues }) {
  const high = issues.filter((item) => item.severity === 'high');
  const medium = issues.filter((item) => item.severity === 'medium');
  const statuses = [...new Set(fiches.map((item) => item.data.statut_utilisateur))];
  return [
    '# Audit pack parcours fiches',
    '',
    `- Source: ${zip}`,
    `- Fiches analysées: ${fiches.length}`,
    `- Statut(s): ${statuses.join(', ')}`,
    `- Anomalies high: ${high.length}`,
    `- Anomalies medium: ${medium.length}`,
    '',
    '## Findings',
    '',
    ...(issues.length === 0
      ? ['Aucune anomalie heuristique détectée.']
      : issues.map(
          (item) =>
            `- [${item.severity}] ${item.activity} (${item.file}) : ${item.reason}`
        )),
    '',
    '## Notes',
    '',
    '- Cet audit est heuristique: il détecte surtout les dérives de template et les textes manifestement hors domaine.',
    '- Avant import en production d’un nouveau statut, relire au minimum les fiches remontées ici.',
    '',
  ].join('\n');
}

function main() {
  const args = readArgs(process.argv.slice(2));
  const jsonDir = extractPack(args.zip);
  const fiches = loadFiches(jsonDir);
  const issues = findIssues(fiches);
  const report = renderReport({ zip: args.zip, fiches, issues });
  if (args.out) {
    fs.writeFileSync(args.out, report);
  }
  process.stdout.write(report);
}

main();