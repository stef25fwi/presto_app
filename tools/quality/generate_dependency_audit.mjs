#!/usr/bin/env node

/**
 * Génère le rapport d'audit des dépendances npm (racine + functions).
 *
 * Ce générateur vivait auparavant en heredoc dans
 * `.github/workflows/dependency-audit-report.yml` : il n'était donc ni
 * testable, ni exécutable en local, et le workflow ne se déclenchait que sur
 * une branche d'audit obsolète — d'où un `docs/DEPENDENCY_AUDIT.md` périmé.
 *
 * Usage :
 *   node tools/quality/generate_dependency_audit.mjs                  # écrit le rapport
 *   node tools/quality/generate_dependency_audit.mjs --check          # échoue si périmé
 *   node tools/quality/generate_dependency_audit.mjs --verify-report  # lit le rapport versionné
 *
 * `--verify-report` ne relance pas `npm audit` : il valide uniquement le
 * rapport committé. C'est ce mode qu'utilise la matrice de contrôles sécurité,
 * qui doit rester exécutable sans `node_modules` installés.
 */

import { execFile } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export const WORKSPACES = [
  { id: 'racine', dir: '.' },
  { id: 'functions', dir: 'functions' },
];

const SEVERITY_ORDER = { critical: 4, high: 3, moderate: 2, low: 1, info: 0 };

/** Sévérités qui font échouer la barrière de sécurité. */
export const BLOCKING_SEVERITIES = ['critical', 'high'];

/**
 * `npm audit --json` sort en code 1 dès qu'une vulnérabilité existe : on lit
 * donc stdout même en cas d'échec, et on ne relaie que les vraies erreurs.
 */
export async function runNpmAudit(cwd) {
  try {
    const { stdout } = await execFileAsync(
      'npm',
      ['audit', '--json'],
      { cwd, maxBuffer: 64 * 1024 * 1024 },
    );
    return JSON.parse(stdout);
  } catch (error) {
    if (typeof error.stdout === 'string' && error.stdout.trim().startsWith('{')) {
      return JSON.parse(error.stdout);
    }
    throw error;
  }
}

export function summarize(report) {
  const counts = report.metadata?.vulnerabilities ?? {};
  const vulnerabilities = Object.entries(report.vulnerabilities ?? {}).sort(
    (a, b) =>
      (SEVERITY_ORDER[b[1].severity] ?? 0) - (SEVERITY_ORDER[a[1].severity] ?? 0)
      || a[0].localeCompare(b[0]),
  );
  return { counts, vulnerabilities };
}

export function renderMarkdown(workspaces) {
  const lines = [
    '# Audit des dépendances npm',
    '',
    'Rapport reproductible généré par `tools/quality/generate_dependency_audit.mjs`',
    'à partir des `package-lock.json` versionnés.',
    '',
    'Régénérer après toute modification de dépendance :',
    '',
    '```bash',
    'node tools/quality/generate_dependency_audit.mjs',
    '```',
    '',
  ];

  for (const { id, counts, vulnerabilities } of workspaces) {
    lines.push(
      `## Espace \`${id}\``,
      '',
      `- Critiques : **${counts.critical ?? 0}**`,
      `- Hautes : **${counts.high ?? 0}**`,
      `- Modérées : **${counts.moderate ?? 0}**`,
      `- Faibles : **${counts.low ?? 0}**`,
      '',
    );

    if (vulnerabilities.length === 0) {
      lines.push('Aucune vulnérabilité connue.', '');
      continue;
    }

    lines.push(
      '| Module | Sévérité | Direct | Correctif disponible | Dépendances affectées |',
      '|---|---|---:|---:|---|',
    );
    for (const [name, item] of vulnerabilities) {
      const effects = Array.isArray(item.effects) ? item.effects.join(', ') : '';
      lines.push(
        `| ${name} | ${item.severity} | ${item.isDirect ? 'oui' : 'non'} `
        + `| ${item.fixAvailable ? 'oui' : 'non'} | ${effects} |`,
      );
    }
    lines.push('');
  }

  return `${lines.join('\n')}\n`;
}

export function blockingFindings(workspaces) {
  const findings = [];
  for (const { id, counts } of workspaces) {
    for (const severity of BLOCKING_SEVERITIES) {
      const count = counts[severity] ?? 0;
      if (count > 0) findings.push(`${id}:${severity}=${count}`);
    }
  }
  return findings;
}

export async function collect(rootDir) {
  const workspaces = [];
  for (const workspace of WORKSPACES) {
    const report = await runNpmAudit(path.join(rootDir, workspace.dir));
    workspaces.push({ ...workspace, ...summarize(report), report });
  }
  return workspaces;
}

/** Valide le rapport versionné sans relancer `npm audit`. */
export async function verifyCommittedReport(rootDir) {
  const jsonPath = path.join(rootDir, 'docs/DEPENDENCY_AUDIT.json');
  const raw = await fs.readFile(jsonPath, 'utf8').catch(() => null);
  if (raw === null) {
    return { ok: false, reason: 'docs/DEPENDENCY_AUDIT.json est absent.' };
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return { ok: false, reason: 'docs/DEPENDENCY_AUDIT.json est illisible.' };
  }

  const missing = WORKSPACES.map(({ id }) => id).filter((id) => !parsed[id]);
  if (missing.length > 0) {
    return { ok: false, reason: `Espaces absents du rapport : ${missing.join(', ')}.` };
  }

  const findings = blockingFindings(
    Object.entries(parsed).map(([id, counts]) => ({ id, counts })),
  );
  if (findings.length > 0) {
    return { ok: false, reason: `Vulnérabilités bloquantes : ${findings.join(', ')}.` };
  }
  return { ok: true, reason: 'Rapport versionné sain (aucune vulnérabilité haute ou critique).' };
}

async function main() {
  const rootDir = process.cwd();
  const check = process.argv.includes('--check');

  if (process.argv.includes('--verify-report')) {
    const { ok, reason } = await verifyCommittedReport(rootDir);
    (ok ? console.log : console.error)(reason);
    if (!ok) process.exitCode = 2;
    return;
  }

  const workspaces = await collect(rootDir);

  const markdown = renderMarkdown(workspaces);
  const json = `${JSON.stringify(
    Object.fromEntries(
      workspaces.map(({ id, counts }) => [id, counts]),
    ),
    null,
    2,
  )}\n`;

  const markdownPath = path.join(rootDir, 'docs/DEPENDENCY_AUDIT.md');
  const jsonPath = path.join(rootDir, 'docs/DEPENDENCY_AUDIT.json');

  if (check) {
    const stale = [];
    for (const [file, expected] of [[markdownPath, markdown], [jsonPath, json]]) {
      const actual = await fs.readFile(file, 'utf8').catch(() => null);
      if (actual !== expected) stale.push(path.relative(rootDir, file));
    }
    const findings = blockingFindings(workspaces);
    if (stale.length > 0) {
      console.error(
        `Rapport de dépendances périmé : ${stale.join(', ')}. `
        + 'Exécuter `node tools/quality/generate_dependency_audit.mjs`.',
      );
    }
    if (findings.length > 0) {
      console.error(`Vulnérabilités bloquantes : ${findings.join(', ')}.`);
    }
    if (stale.length > 0 || findings.length > 0) {
      process.exitCode = 2;
      return;
    }
    console.log('Rapport de dépendances à jour, aucune vulnérabilité bloquante.');
    return;
  }

  await fs.writeFile(markdownPath, markdown, 'utf8');
  await fs.writeFile(jsonPath, json, 'utf8');
  console.log(`Rapport écrit : ${path.relative(rootDir, markdownPath)}`);
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
