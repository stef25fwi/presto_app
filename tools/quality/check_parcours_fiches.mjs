#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const DEFAULT_RULES = 'quality/parcours_fiches_audit_rules.json';
const DEFAULT_OUTPUT = 'build/quality/parcours-fiches-audit-report.json';

function parseArgs(argv) {
  const args = { roots: [], rules: DEFAULT_RULES, output: DEFAULT_OUTPUT, enforce: false, failOnWarnings: false };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--root') args.roots.push(argv[++index]);
    else if (value === '--rules') args.rules = argv[++index];
    else if (value === '--output') args.output = argv[++index];
    else if (value === '--enforce') args.enforce = true;
    else if (value === '--fail-on-warnings') args.failOnWarnings = true;
  }
  return args;
}

function stripDiacritics(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

export function normalizeText(value) {
  return stripDiacritics(String(value ?? ''))
    .toLowerCase()
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function getPath(object, dottedPath) {
  return dottedPath.split('.').reduce((value, key) => value?.[key], object);
}

function flattenStrings(value, currentPath = '', result = []) {
  if (typeof value === 'string') {
    result.push({ path: currentPath, value });
  } else if (Array.isArray(value)) {
    value.forEach((item, index) => flattenStrings(item, `${currentPath}[${index}]`, result));
  } else if (value && typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      flattenStrings(item, currentPath ? `${currentPath}.${key}` : key, result);
    }
  }
  return result;
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

function issue(severity, code, message, field = null) {
  return { severity, code, message, field };
}

function duplicateIssues(fiche, rules) {
  const issues = [];
  for (const collectionPath of rules.duplicateCollections ?? []) {
    const value = getPath(fiche, collectionPath);
    if (!Array.isArray(value)) continue;
    const seen = new Map();
    for (const item of value) {
      const normalized = normalizeText(typeof item === 'string' ? item : JSON.stringify(item));
      if (normalized.length < 8) continue;
      if (seen.has(normalized)) {
        issues.push(issue('error', 'duplicate-within-collection', `Information répétée dans ${collectionPath}`, collectionPath));
      } else {
        seen.set(normalized, true);
      }
    }
  }
  for (const [leftPath, rightPath] of rules.crossDuplicatePairs ?? []) {
    const left = getPath(fiche, leftPath);
    const right = getPath(fiche, rightPath);
    const leftValues = Array.isArray(left) ? left : typeof left === 'string' ? [left] : [];
    const rightValues = Array.isArray(right) ? right : typeof right === 'string' ? [right] : [];
    const leftSet = new Set(leftValues.map(normalizeText).filter((value) => value.length >= 12));
    for (const item of rightValues) {
      if (leftSet.has(normalizeText(item))) {
        issues.push(issue('warning', 'duplicate-across-sections', `Information répétée entre ${leftPath} et ${rightPath}`, `${leftPath}|${rightPath}`));
        break;
      }
    }
  }
  return issues;
}

function compatibilityIssues(fiche, rules) {
  const issues = [];
  const activity = String(fiche.activite ?? '');
  const family = String(fiche.famille ?? '');
  const allText = flattenStrings(fiche).map((entry) => entry.value).join('\n');
  for (const rule of rules.compatibilityRules ?? []) {
    if (rule.activityRegex && !new RegExp(rule.activityRegex, 'i').test(activity)) continue;
    if (rule.unlessFamilyRegex && new RegExp(rule.unlessFamilyRegex, 'i').test(family)) continue;
    if (rule.forbiddenFamilyRegex && new RegExp(rule.forbiddenFamilyRegex, 'i').test(family)) {
      issues.push(issue(rule.severity, rule.id, `Famille incompatible avec l'activité : ${family}`, 'famille'));
    }
    for (const term of rule.forbiddenTerms ?? []) {
      if (allText.toLocaleLowerCase('fr').includes(term.toLocaleLowerCase('fr'))) {
        issues.push(issue(rule.severity, rule.id, `Contenu potentiellement étranger à l'activité : « ${term} »`));
      }
    }
  }
  return issues;
}

function chronologyIssues(fiche, rules) {
  const steps = getPath(fiche, 'parcours.4_demarches');
  if (!Array.isArray(steps) || steps.length === 0) {
    return [issue('error', 'missing-steps', 'Le parcours ne contient aucune démarche ordonnée.', 'parcours.4_demarches')];
  }
  const ranks = [];
  for (const step of steps) {
    const normalized = normalizeText(step);
    let rank = -1;
    let bestScore = 0;
    for (const [phaseIndex, phase] of (rules.stepOrder ?? []).entries()) {
      const score = phase.terms.filter((term) => normalized.includes(normalizeText(term))).length;
      if (score > bestScore) {
        bestScore = score;
        rank = phaseIndex;
      }
    }
    if (rank >= 0) ranks.push(rank);
  }
  let previous = -1;
  for (const rank of ranks) {
    if (rank < previous) {
      return [issue('warning', 'chronology-order', 'Les démarches semblent revenir en arrière dans la chronologie.', 'parcours.4_demarches')];
    }
    previous = rank;
  }
  const declarationStep = steps.findIndex((step) => {
    const normalized = normalizeText(step);
    return normalized.includes('guichet unique') || normalized.includes('immatricul') || normalized.includes('declarer l activite');
  });
  const aidsStep = steps.findIndex((step) => {
    const normalized = normalizeText(step);
    return normalized.includes('aides') || normalized.includes('acre') || normalized.includes('financement');
  });
  if (declarationStep >= 0 && aidsStep >= 0 && aidsStep > declarationStep) {
    return [issue('warning', 'aids-after-creation', 'Les aides apparaissent après la déclaration alors que certaines doivent être vérifiées avant la création.', 'parcours.4_demarches')];
  }
  return [];
}

function sourceIssues(fiche) {
  const issues = [];
  const sources = fiche.sources_officielles;
  if (!Array.isArray(sources) || sources.length === 0) {
    issues.push(issue('error', 'missing-sources', 'Aucune source officielle n’est renseignée.', 'sources_officielles'));
    return issues;
  }
  for (const source of sources) {
    if (typeof source !== 'string' || !source.startsWith('https://')) {
      issues.push(issue('error', 'invalid-source', `Source non sécurisée ou invalide : ${source}`, 'sources_officielles'));
    }
  }
  return issues;
}

function metadataIssues(fiche, rules) {
  const issues = [];
  for (const field of rules.requiredFields ?? []) {
    const value = getPath(fiche, field);
    if (value === undefined || value === null || value === '' || (Array.isArray(value) && value.length === 0)) {
      issues.push(issue('error', 'missing-required-field', `Champ obligatoire absent : ${field}`, field));
    }
  }
  for (const field of rules.requiredReviewMetadata ?? []) {
    const value = fiche[field];
    if (value === undefined || value === null || value === '') {
      issues.push(issue('warning', 'missing-review-metadata', `Métadonnée de révision absente : ${field}`, field));
    }
  }
  if (fiche.review_status && !(rules.allowedReviewStatuses ?? []).includes(fiche.review_status)) {
    issues.push(issue('error', 'invalid-review-status', `Statut de révision inconnu : ${fiche.review_status}`, 'review_status'));
  }
  for (const field of ['version', 'reviewed_at', 'next_review_at']) {
    if (fiche[field] && !/^\d{4}-\d{2}-\d{2}$/.test(String(fiche[field]))) {
      issues.push(issue('error', 'invalid-date', `Date invalide dans ${field}; format attendu AAAA-MM-JJ.`, field));
    }
  }
  return issues;
}

function visibleLanguageIssues(fiche, rules) {
  const allText = flattenStrings(fiche).map((entry) => entry.value).join('\n');
  return (rules.visibleEnglishTokens ?? [])
    .filter((token) => allText.includes(token))
    .map((token) => issue('warning', 'visible-english-token', `Libellé anglais visible : ${token}`));
}

function fiscalIssues(fiche) {
  const issues = [];
  const fiscality = fiche.fiscalite;
  if (!fiscality || typeof fiscality !== 'object') return issues;
  for (const [key, value] of Object.entries(fiscality)) {
    const hasAmount = /\d/.test(String(value));
    const datedKey = /20\d{2}/.test(key);
    if (hasAmount && !datedKey && !['compte_dedie', 'cfe'].includes(key)) {
      issues.push(issue('warning', 'undated-regulatory-value', `Valeur réglementaire non datée : ${key}`, `fiscalite.${key}`));
    }
  }
  return issues;
}

export function auditFiche(fiche, rules, file = '<memory>') {
  const issues = [
    ...metadataIssues(fiche, rules),
    ...sourceIssues(fiche),
    ...duplicateIssues(fiche, rules),
    ...compatibilityIssues(fiche, rules),
    ...chronologyIssues(fiche, rules),
    ...visibleLanguageIssues(fiche, rules),
    ...fiscalIssues(fiche),
  ];
  const highRisk = new RegExp(rules.highRiskFamilyRegex ?? '$^', 'i').test(`${fiche.famille ?? ''} ${fiche.type_activite ?? ''}`);
  const counts = issues.reduce((acc, entry) => {
    acc[entry.severity] = (acc[entry.severity] ?? 0) + 1;
    return acc;
  }, {});
  return {
    file,
    id: fiche.id_fiche ?? fiche.id ?? path.basename(file, '.json'),
    activity: fiche.activite ?? '',
    family: fiche.famille ?? '',
    status: fiche.review_status ?? 'non_auditee',
    highRisk,
    validForPublication: issues.every((entry) => !['blocker', 'error'].includes(entry.severity)) && fiche.review_status === 'validee',
    counts,
    issues,
  };
}

export function auditDirectory({ roots, rulesPath = DEFAULT_RULES }) {
  const rules = readJson(rulesPath);
  const files = roots.flatMap(collectJsonFiles);
  const seenIds = new Map();
  const fiches = [];
  for (const file of files) {
    let fiche;
    try {
      fiche = readJson(file);
    } catch (error) {
      fiches.push({ file, id: path.basename(file, '.json'), activity: '', family: '', status: 'non_auditee', highRisk: false, validForPublication: false, counts: { blocker: 1 }, issues: [issue('blocker', 'invalid-json', error.message)] });
      continue;
    }
    const result = auditFiche(fiche, rules, file);
    if (seenIds.has(result.id)) {
      result.issues.push(issue('blocker', 'duplicate-id', `Identifiant également utilisé par ${seenIds.get(result.id)}`, 'id_fiche'));
      result.counts.blocker = (result.counts.blocker ?? 0) + 1;
      result.validForPublication = false;
    } else {
      seenIds.set(result.id, file);
    }
    fiches.push(result);
  }
  const totals = { blocker: 0, error: 0, warning: 0 };
  for (const fiche of fiches) {
    for (const severity of Object.keys(totals)) totals[severity] += fiche.counts[severity] ?? 0;
  }
  const byStatus = {};
  for (const fiche of fiches) byStatus[fiche.status] = (byStatus[fiche.status] ?? 0) + 1;
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    inventory: {
      totalFiles: fiches.length,
      highRiskFiles: fiches.filter((item) => item.highRisk).length,
      publishableFiles: fiches.filter((item) => item.validForPublication).length,
      byStatus,
    },
    totals,
    allBlockingChecksPassed: totals.blocker === 0 && totals.error === 0,
    fiches,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const rules = readJson(args.rules);
  const roots = args.roots.length > 0 ? args.roots : rules.catalogRoots;
  const report = auditDirectory({ roots, rulesPath: args.rules });
  fs.mkdirSync(path.dirname(args.output), { recursive: true });
  fs.writeFileSync(args.output, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`parcours fiches: ${report.inventory.totalFiles} fiches, ${report.totals.blocker} blocages, ${report.totals.error} erreurs, ${report.totals.warning} avertissements`);
  console.log(`publiables: ${report.inventory.publishableFiles}/${report.inventory.totalFiles}`);
  if (args.enforce && !report.allBlockingChecksPassed) process.exitCode = 1;
  if (args.failOnWarnings && report.totals.warning > 0) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
