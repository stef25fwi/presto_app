#!/usr/bin/env node
// Vérifie que les textes de la fiche Play Store tiennent dans les limites de
// caractères imposées par la console. Play tronque sans prévenir : mieux vaut
// s'en apercevoir dans le dépôt que sur la fiche publiée.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const LIMITS = {
  title: 30,
  shortDescription: 80,
  longDescription: 4000
};

const SECTION_PATTERNS = [
  { key: 'title', heading: /^##\s+Titre\b/ },
  { key: 'shortDescription', heading: /^##\s+Description courte\b/ },
  { key: 'longDescription', heading: /^##\s+Description longue\b/ }
];

// Extrait le premier bloc de code qui suit chaque titre de section.
export function extractSections(markdown) {
  const lines = markdown.split('\n');
  const sections = {};

  for (const { key, heading } of SECTION_PATTERNS) {
    const start = lines.findIndex((line) => heading.test(line));
    if (start === -1) continue;

    const fenceStart = lines.findIndex(
      (line, index) => index > start && line.trim() === '```'
    );
    if (fenceStart === -1) continue;

    const fenceEnd = lines.findIndex(
      (line, index) => index > fenceStart && line.trim() === '```'
    );
    if (fenceEnd === -1) continue;

    sections[key] = lines.slice(fenceStart + 1, fenceEnd).join('\n').trim();
  }

  return sections;
}

export function checkSections(sections) {
  const findings = [];

  for (const [key, limit] of Object.entries(LIMITS)) {
    const value = sections[key];
    if (value === undefined) {
      findings.push({ key, status: 'missing', length: 0, limit });
      continue;
    }
    // Play compte les caractères, pas les octets : `iliprestō` vaut 9.
    const length = [...value].length;
    findings.push({
      key,
      status: length > limit ? 'too_long' : 'ok',
      length,
      limit
    });
  }

  return findings;
}

function main() {
  const path = process.argv[2] ?? 'marketing/play-store/listing-fr.md';
  const findings = checkSections(extractSections(readFileSync(path, 'utf8')));

  for (const finding of findings) {
    const marker = finding.status === 'ok' ? 'ok' : finding.status.toUpperCase();
    console.log(
      `${marker.padEnd(9)} ${finding.key}: ${finding.length}/${finding.limit}`
    );
  }

  const failures = findings.filter((finding) => finding.status !== 'ok');
  if (failures.length > 0) {
    console.error(
      `\n${failures.length} texte(s) hors limite dans ${path} — la fiche serait tronquée ou refusée.`
    );
    process.exit(1);
  }
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  main();
}
