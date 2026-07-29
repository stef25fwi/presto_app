#!/usr/bin/env node

/**
 * Vérifie que `quality/secrets-inventory.json` décrit exactement les secrets
 * réellement déclarés dans le code (`defineSecret("...")`).
 *
 * Un inventaire de secrets rédigé à la main dérive dès le premier ajout de
 * secret. Ce contrôle le rend vérifiable : tout secret ajouté au code sans
 * gouvernance déclarée, ou toute entrée d'inventaire devenue orpheline, fait
 * échouer la barrière.
 *
 * Il ne lit aucune valeur de secret : uniquement les identifiants.
 *
 * Usage : node tools/quality/check_secrets_inventory.mjs
 */

import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFINE_SECRET_PATTERN = /defineSecret\(\s*["'`]([A-Z0-9_]+)["'`]\s*\)/g;
const REQUIRED_FIELDS = ['name', 'owner', 'purpose'];

export function extractDeclaredSecrets(source) {
  return [...source.matchAll(DEFINE_SECRET_PATTERN)].map((match) => match[1]);
}

async function listTypeScriptFiles(root) {
  const entries = await readdir(root, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const absolute = path.join(root, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listTypeScriptFiles(absolute)));
      continue;
    }
    if (entry.isFile() && entry.name.endsWith('.ts')) files.push(absolute);
  }
  return files;
}

export function compareInventory(sourceSecrets, inventory) {
  const failures = [];
  const declared = new Set(sourceSecrets);
  const entries = inventory.secrets ?? [];
  const inventoried = new Set(entries.map((entry) => entry.name));

  for (const name of [...declared].sort()) {
    if (!inventoried.has(name)) {
      failures.push(`secret-non-inventorie:${name}`);
    }
  }
  for (const name of [...inventoried].sort()) {
    if (!declared.has(name)) {
      failures.push(`entree-orpheline:${name}`);
    }
  }

  const seen = new Set();
  for (const entry of entries) {
    if (seen.has(entry.name)) failures.push(`doublon-inventaire:${entry.name}`);
    seen.add(entry.name);
    for (const field of REQUIRED_FIELDS) {
      if (!entry[field]) {
        failures.push(`champ-manquant:${entry.name ?? 'inconnu'}.${field}`);
      }
    }
  }

  return {
    ready: failures.length === 0,
    declaredCount: declared.size,
    inventoriedCount: inventoried.size,
    failures,
  };
}

export async function evaluateSecretsInventory({ rootDir = process.cwd() } = {}) {
  const inventory = JSON.parse(
    await readFile(path.join(rootDir, 'quality/secrets-inventory.json'), 'utf8'),
  );
  const files = await listTypeScriptFiles(path.join(rootDir, 'functions/src'));
  const sourceSecrets = [];
  for (const file of files) {
    sourceSecrets.push(...extractDeclaredSecrets(await readFile(file, 'utf8')));
  }
  return compareInventory(sourceSecrets, inventory);
}

async function main() {
  const report = await evaluateSecretsInventory();
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  if (!report.ready) process.exitCode = 2;
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
