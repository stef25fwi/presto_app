#!/usr/bin/env node
/**
 * Contrôle statique de l'autorité d'administration (point 9).
 *
 * La matrice `quality/admin-authority-matrix.json` déclare, opération par
 * opération, les rôles autorisés, l'état d'App Check et la trace d'audit
 * attendue. Ce vérificateur confronte cette déclaration au code réel dans les
 * deux sens :
 *
 * 1. chaque opération déclarée doit exister et appliquer exactement les rôles
 *    annoncés ;
 * 2. toute opération d'administration présente dans le code mais absente de la
 *    matrice fait échouer le contrôle — c'est la détection de dérive, sans
 *    laquelle une nouvelle porte d'entrée passerait inaperçue.
 *
 * Il vérifie enfin que les champs de rôle restent inscriptibles uniquement
 * côté serveur dans les règles Firestore.
 */
import fs from 'node:fs';
import path from 'node:path';

const matrixPath = 'quality/admin-authority-matrix.json';
const sourceRoot = path.join('functions', 'src');
const ADMIN_ROLES = ['moderator', 'admin', 'superadmin'];

function listTypeScriptFiles(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  return entries.flatMap((entry) => {
    const current = path.join(directory, entry.name);
    if (entry.isDirectory()) return listTypeScriptFiles(current);
    if (!entry.name.endsWith('.ts') || entry.name.endsWith('.test.ts')) return [];
    return [current];
  });
}

/** Découpe un fichier en blocs `export const <nom> = onCall(...)`. */
export function extractCallableBlocks(source) {
  const blocks = new Map();
  const marker = /\nexport const (\w+)\s*=\s*onCall/g;
  const starts = [];
  let match = marker.exec(`\n${source}`);
  while (match) {
    starts.push({ name: match[1], index: match.index });
    match = marker.exec(`\n${source}`);
  }
  for (let index = 0; index < starts.length; index += 1) {
    const start = starts[index];
    const end = index + 1 < starts.length ? starts[index + 1].index : source.length + 1;
    blocks.set(start.name, `\n${source}`.slice(start.index, end));
  }
  return blocks;
}

/** Rôles exigés par un appel `requireAnyRole(acteur, [...], message)`. */
export function rolesFromRequireAnyRole(snippet) {
  const roles = [];
  const pattern = /requireAnyRole\(\s*[\s\S]{0,400}?\[([^\]]*)\]/g;
  let match = pattern.exec(snippet);
  while (match) {
    for (const role of match[1].split(',')) {
      const cleaned = role.replace(/["'\s]/g, '');
      if (cleaned) roles.push(cleaned);
    }
    match = pattern.exec(snippet);
  }
  return [...new Set(roles)].sort();
}

/**
 * Corps d'une fonction de garde locale, accolades équilibrées.
 *
 * La liste de paramètres peut contenir un type littéral entre accolades :
 * le corps commence donc après la parenthèse fermante de la signature, pas à
 * la première accolade rencontrée.
 */
export function extractFunctionBody(source, symbol) {
  const declaration = source.indexOf(`function ${symbol}(`);
  if (declaration < 0) return null;

  // La déclaration s'arrête au prochain élément de premier niveau : le corps
  // est alors le dernier bloc équilibré de cette zone. Les accolades des types
  // de paramètres et du type de retour se referment avant lui.
  const boundary = source
    .slice(declaration)
    .search(/\n(?:export |function |class |const |async function )/);
  const region = boundary > 0
    ? source.slice(declaration, declaration + boundary)
    : source.slice(declaration);

  let best = null;
  for (let index = 0; index < region.length; index += 1) {
    if (region[index] !== '{') continue;
    const close = matchingBrace(region, index);
    if (close < 0) continue;
    if (!best || close > best.close) best = { open: index, close };
  }
  return best ? region.slice(best.open, best.close + 1) : null;
}

function matchingBrace(text, open) {
  let depth = 0;
  for (let index = open; index < text.length; index += 1) {
    if (text[index] === '{') depth += 1;
    else if (text[index] === '}') {
      depth -= 1;
      if (depth === 0) return index;
    }
  }
  return -1;
}

/**
 * Corps d'une garde, augmenté de celui des fonctions locales qu'elle appelle.
 * Une garde qui délègue son test de rôle à un assistant du même fichier reste
 * ainsi vérifiable.
 */
export function resolveGuardScope(source, symbol) {
  const body = extractFunctionBody(source, symbol);
  if (!body) return null;
  const called = new Set(
    [...body.matchAll(/\b([a-z]\w+)\s*\(/g)].map((match) => match[1]),
  );
  let scope = body;
  for (const helper of called) {
    if (helper === symbol) continue;
    const helperBody = extractFunctionBody(source, helper);
    if (helperBody) scope += `\n${helperBody}`;
  }
  return scope;
}

/**
 * Résout l'état d'App Check d'un callable, que les options soient écrites en
 * ligne ou portées par une constante partagée (éventuellement étendue par
 * décomposition).
 */
export function resolveAppCheck(source, block, seen = new Set()) {
  const inline = block.match(/onCall\(\s*\{([\s\S]*?)\}\s*,/);
  if (inline) return appCheckFromOptions(source, inline[1], seen);
  const named = block.match(/onCall\(\s*(\w+)\s*,/);
  if (!named) return 'unknown';
  return appCheckFromConstant(source, named[1], seen);
}

function appCheckFromConstant(source, identifier, seen) {
  if (seen.has(identifier)) return 'unknown';
  seen.add(identifier);
  const declaration = source.match(
    new RegExp(`const ${identifier}\\s*(?::[^=]+)?=\\s*\\{([\\s\\S]*?)\\n\\}`),
  );
  if (!declaration) return 'unknown';
  return appCheckFromOptions(source, declaration[1], seen);
}

function appCheckFromOptions(source, options, seen) {
  const direct = options.match(/enforceAppCheck\s*:\s*([\w.]+)/);
  if (direct) {
    if (direct[1] === 'false') return 'disabled';
    if (direct[1] === 'true' || direct[1] === 'ENFORCE_APP_CHECK') return 'enforced';
    return 'unknown';
  }
  const spread = options.match(/\.\.\.(\w+)/);
  if (spread) return appCheckFromConstant(source, spread[1], seen);
  return 'absent';
}

function readMatrix() {
  if (!fs.existsSync(matrixPath)) {
    throw new Error(`Matrice d'autorité introuvable: ${matrixPath}`);
  }
  const matrix = JSON.parse(fs.readFileSync(matrixPath, 'utf8'));
  if (matrix.schemaVersion !== 1 || matrix.point !== 9) {
    throw new Error("Matrice d'autorité du point 9 invalide.");
  }
  if (!Array.isArray(matrix.operations) || matrix.operations.length === 0) {
    throw new Error("La matrice doit déclarer au moins une opération.");
  }
  return matrix;
}

function checkGuards(matrix, errors) {
  const guards = new Map();
  for (const guard of matrix.guards || []) {
    if (!fs.existsSync(guard.file)) {
      errors.push(`garde ${guard.id}: fichier absent ${guard.file}`);
      continue;
    }
    const source = fs.readFileSync(guard.file, 'utf8');
    const body = resolveGuardScope(source, guard.symbol);
    if (!body) {
      errors.push(`garde ${guard.id}: fonction ${guard.symbol} introuvable`);
      continue;
    }
    const declared = [...guard.roles].sort();
    const found = rolesFromRequireAnyRole(body);
    if (found.length) {
      if (found.join(',') !== declared.join(',')) {
        errors.push(
          `garde ${guard.id}: rôles ${found.join('|') || 'aucun'} au lieu de ${declared.join('|')}`,
        );
      }
    } else {
      // Certaines gardes historiques testent les revendications directement.
      const mentionsRoles = declared.every((role) => body.includes(role));
      if (!mentionsRoles) {
        errors.push(`garde ${guard.id}: aucun contrôle de rôle détecté`);
      }
    }
    guards.set(guard.id, declared);
  }
  return guards;
}

function checkOperations(matrix, guards, errors) {
  const declared = new Set();
  const rows = [];
  for (const operation of matrix.operations) {
    const { callable, file } = operation;
    declared.add(callable);
    if (!fs.existsSync(file)) {
      errors.push(`${callable}: fichier absent ${file}`);
      continue;
    }
    const source = fs.readFileSync(file, 'utf8');
    const block = extractCallableBlocks(source).get(callable);
    if (!block) {
      errors.push(`${callable}: aucun onCall exporté dans ${file}`);
      continue;
    }

    const expectedRoles = [...operation.roles].sort();
    let actualRoles = rolesFromRequireAnyRole(block);
    if (!actualRoles.length && operation.guard) {
      if (!block.includes(operation.guard.split('@')[0])) {
        errors.push(`${callable}: la garde ${operation.guard} n'est pas appelée`);
      }
      actualRoles = guards.get(operation.guard) || [];
      if (!actualRoles.length) {
        errors.push(`${callable}: garde déclarée ${operation.guard} non résolue`);
      }
    }
    if (!actualRoles.length) {
      errors.push(`${callable}: aucune exigence de rôle détectée`);
    } else if (actualRoles.join(',') !== expectedRoles.join(',')) {
      errors.push(
        `${callable}: rôles ${actualRoles.join('|')} au lieu de ${expectedRoles.join('|')}`,
      );
    }

    const appCheck = resolveAppCheck(source, block);
    if (appCheck !== operation.appCheck) {
      errors.push(`${callable}: App Check ${appCheck} au lieu de ${operation.appCheck}`);
    }
    if (operation.appCheck === 'disabled' && operation.appCheckWaiver?.status !== 'open') {
      errors.push(`${callable}: App Check désactivé sans dérogation ouverte et datée`);
    }

    const audit = operation.audit || 'none';
    if (audit !== 'none') {
      if (!block.includes(audit)) {
        errors.push(`${callable}: trace d'audit ${audit} absente du handler`);
      }
    } else if (operation.mutating) {
      // Une mutation d'administration sans trace n'est acceptable que sous
      // dérogation écrite : sinon la décision devient inexplicable après coup.
      if (operation.auditWaiver?.status !== 'accepted' || !operation.auditWaiver?.reason) {
        errors.push(`${callable}: mutation d'administration non journalisée`);
      }
    }

    rows.push({
      callable,
      file,
      roles: expectedRoles,
      appCheck,
      audit: operation.audit || 'none',
      mutating: Boolean(operation.mutating),
    });
  }
  return { declared, rows };
}

function checkDrift(declared, errors) {
  const found = [];
  for (const file of listTypeScriptFiles(sourceRoot)) {
    const source = fs.readFileSync(file, 'utf8');
    for (const [name, block] of extractCallableBlocks(source)) {
      const roles = rolesFromRequireAnyRole(block);
      const guardsAdmin =
        roles.some((role) => ADMIN_ROLES.includes(role)) ||
        /require(Admin|AdminAccess)\s*\(/.test(block);
      const looksAdmin =
        /admin/i.test(name) || file.includes(`${path.sep}admin${path.sep}`);
      if (guardsAdmin || looksAdmin) found.push(name);
    }
  }
  for (const name of new Set(found)) {
    if (!declared.has(name)) {
      errors.push(
        `${name}: opération d'administration non déclarée dans ${matrixPath}`,
      );
    }
  }
  return [...new Set(found)].sort();
}

function checkClientElevation(matrix, errors) {
  const config = matrix.clientElevationProtection;
  if (!config) {
    errors.push("La matrice ne déclare aucune protection contre l'élévation client.");
    return { protectedFields: [] };
  }
  if (!fs.existsSync(config.rulesFile)) {
    errors.push(`Règles introuvables: ${config.rulesFile}`);
    return { protectedFields: [] };
  }
  const rules = fs.readFileSync(config.rulesFile, 'utf8');
  const block = rules.match(/function protectedUserFields\(\)\s*\{([\s\S]*?)\n\s*\}/);
  if (!block) {
    errors.push('protectedUserFields() est absente des règles Firestore.');
    return { protectedFields: [] };
  }
  const listed = [...block[1].matchAll(/'([^']+)'/g)].map((entry) => entry[1]);
  const missing = config.protectedUserFields.filter((field) => !listed.includes(field));
  if (missing.length) {
    errors.push(
      `champs de rôle inscriptibles côté client: ${missing.join(', ')}`,
    );
  }
  if (!/protectedUserFields\(\)/.test(rules.replace(block[0], ''))) {
    errors.push('protectedUserFields() est déclarée mais jamais appliquée.');
  }
  return { protectedFields: listed, missing };
}

export function auditAdminAuthority() {
  const errors = [];
  const matrix = readMatrix();
  const guards = checkGuards(matrix, errors);
  const { declared, rows } = checkOperations(matrix, guards, errors);
  const discovered = checkDrift(declared, errors);
  const elevation = checkClientElevation(matrix, errors);

  return {
    point: 9,
    declaredOperations: matrix.operations.length,
    discoveredOperations: discovered.length,
    appCheckWaivers: matrix.operations
      .filter((operation) => operation.appCheck === 'disabled')
      .map((operation) => operation.callable),
    unloggedMutations: matrix.operations
      .filter((operation) => operation.mutating && (operation.audit || 'none') === 'none')
      .map((operation) => operation.callable),
    protectedUserFields: elevation.protectedFields.length,
    operations: rows.filter((row) => row.file),
    errors,
    complete: errors.length === 0,
  };
}

const invokedDirectly =
  process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename);

if (invokedDirectly) {
  const report = auditAdminAuthority();
  const outputPath = path.join('build', 'quality', 'admin-authority-report.json');
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));

  if (report.errors.length) {
    console.error(`Autorité d'administration non conforme: ${report.errors.join(' | ')}`);
    process.exitCode = 1;
  }
}
