#!/usr/bin/env node

import { execFile } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

/**
 * Trois natures de contrôle, par ordre de force décroissante :
 *
 * - `automated` : le contrôle porte une commande, réellement exécutée ici.
 *   Son statut est *dérivé* du code de sortie, jamais déclaré à la main.
 * - `source-control` : vérifiable par la seule présence d'un artefact versionné.
 * - `external-evidence` : dépend d'une console externe (Firebase, Google Cloud)
 *   hors de portée du dépôt. Son statut reste déclaré par un opérateur humain,
 *   preuve à l'appui.
 *
 * Auparavant tout contrôle se résumait à « le champ status vaut verified et un
 * fichier existe » : un contrôle pouvait donc être marqué vérifié sans que
 * rien ne soit vérifié. Les contrôles `automated` ferment cette faille.
 */
export const AUTOMATED_KIND = 'automated';

async function runControlCommand(command, rootDir) {
  if (!Array.isArray(command) || command.length === 0) {
    return { ok: false, detail: 'commande-invalide' };
  }
  const [binary, ...args] = command;
  try {
    await execFileAsync(binary, args, {
      cwd: rootDir,
      maxBuffer: 16 * 1024 * 1024,
    });
    return { ok: true, detail: 'commande-reussie' };
  } catch (error) {
    const code = typeof error.code === 'number' ? error.code : 'erreur';
    return { ok: false, detail: `commande-echouee:${code}` };
  }
}

export async function evaluateSecurityControls({
  rootDir = process.cwd(),
  enforce = false,
  runCommands = true,
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

    let status = control.status;
    let commandResult = null;
    if (control.kind === AUTOMATED_KIND) {
      if (runCommands) {
        commandResult = await runControlCommand(control.command, rootDir);
        // Le statut d'un contrôle automatisé est prouvé, pas déclaré.
        status = commandResult.ok ? 'verified' : 'failed';
      } else {
        status = 'skipped';
      }
    }

    const complete = status === 'verified' && evidenceExists;
    controls.push({
      ...control,
      status,
      evidenceExists,
      complete,
      ...(commandResult ? { commandResult: commandResult.detail } : {}),
    });

    if (control.required && control.kind === 'source-control' && !complete) {
      failures.push(`${control.id}:source-control-not-verifiable`);
    }
    if (control.required && control.kind === AUTOMATED_KIND && runCommands && !complete) {
      failures.push(`${control.id}:automated-control-failed`);
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
