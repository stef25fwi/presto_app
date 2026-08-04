#!/usr/bin/env node
/**
 * Contrôle de couverture du corpus d'évaluation IA (point 8).
 *
 * Un jeu d'évaluation qui n'exerce qu'un accent ou qu'un conteneur audio ne
 * prouve rien sur la qualité réellement servie. Ce vérificateur impose donc
 * une couverture minimale, l'unicité des cas et la cohérence des types MIME,
 * avant que les évaluations réelles ne soient lancées.
 */
import fs from 'node:fs';
import path from 'node:path';

const REQUIRED_ACCENTS = ['fr-FR', 'fr-BE', 'fr-CH'];
const REQUIRED_AUDIO_FORMATS = ['wav', 'mp3', 'ogg', 'webm', 'flac', 'm4a'];
const REQUIRED_IMAGE_FORMATS = ['jpg', 'png', 'webp'];
const MIN_CASES_PER_ACCENT = 2;

const AUDIO_CONTENT_TYPES = {
  wav: 'audio/wav',
  mp3: 'audio/mpeg',
  ogg: 'audio/ogg',
  webm: 'audio/webm',
  flac: 'audio/flac',
  m4a: 'audio/mp4',
};

const IMAGE_CONTENT_TYPES = {
  jpg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
};

const transcriptionPath = 'functions/evals/transcription_cases.jsonl';
const visionPath = 'functions/evals/vision_cases.jsonl';

function readJsonl(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Corpus introuvable: ${filePath}`);
  }
  return fs
    .readFileSync(filePath, 'utf8')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => {
      try {
        return JSON.parse(line);
      } catch {
        throw new Error(`Ligne JSON invalide dans ${filePath} (ligne ${index + 1})`);
      }
    });
}

function normalizedFormat(value) {
  const format = String(value || '').toLowerCase();
  return format === 'jpeg' ? 'jpg' : format;
}

function formatOf(fixture, mediaKey) {
  const declared =
    fixture.format || path.extname(String(fixture[mediaKey] || '')).replace('.', '');
  return normalizedFormat(declared);
}

function checkUnique(fixtures, mediaKey, errors, label) {
  const ids = new Set();
  const media = new Set();
  for (const fixture of fixtures) {
    if (!fixture.id) {
      errors.push(`${label}: un cas sans identifiant`);
      continue;
    }
    if (ids.has(fixture.id)) errors.push(`${label}: identifiant dupliqué ${fixture.id}`);
    ids.add(fixture.id);
    const file = fixture[mediaKey];
    if (!file) {
      errors.push(`${label}: média manquant pour ${fixture.id}`);
      continue;
    }
    if (media.has(file)) errors.push(`${label}: média dupliqué ${file}`);
    media.add(file);
  }
}

function checkTranscription(fixtures, errors) {
  checkUnique(fixtures, 'audio', errors, 'transcription');
  const perAccent = new Map();
  for (const fixture of fixtures) {
    const accent = String(fixture.accent || '').trim();
    const format = formatOf(fixture, 'audio');
    if (!accent) {
      errors.push(`transcription: accent manquant pour ${fixture.id}`);
    } else {
      perAccent.set(accent, (perAccent.get(accent) || 0) + 1);
    }
    if (!REQUIRED_AUDIO_FORMATS.includes(format)) {
      errors.push(`transcription: format non supporté pour ${fixture.id} (${format || 'absent'})`);
    } else if (
      fixture.contentType &&
      fixture.contentType !== AUDIO_CONTENT_TYPES[format]
    ) {
      errors.push(
        `transcription: content-type ${fixture.contentType} incohérent avec ${format} pour ${fixture.id}`,
      );
    }
    if (!fixture.expectedText || !Array.isArray(fixture.entities) || !fixture.entities.length) {
      errors.push(`transcription: attendus incomplets pour ${fixture.id}`);
    }
    if (fixture.sourceType !== 'synthetic') {
      errors.push(`transcription: ${fixture.id} n'est pas déclaré synthétique`);
    }
  }

  const accents = [...perAccent.keys()].sort();
  const formats = [...new Set(fixtures.map((fixture) => formatOf(fixture, 'audio')))].sort();
  const missingAccents = REQUIRED_ACCENTS.filter((accent) => !accents.includes(accent));
  const missingFormats = REQUIRED_AUDIO_FORMATS.filter((format) => !formats.includes(format));
  if (missingAccents.length) errors.push(`accents manquants: ${missingAccents.join(', ')}`);
  if (missingFormats.length) errors.push(`formats audio manquants: ${missingFormats.join(', ')}`);
  for (const accent of REQUIRED_ACCENTS) {
    const count = perAccent.get(accent) || 0;
    if (count && count < MIN_CASES_PER_ACCENT) {
      errors.push(`accent ${accent}: ${count} cas au lieu de ${MIN_CASES_PER_ACCENT} minimum`);
    }
  }

  return {
    cases: fixtures.length,
    accents,
    formats,
    casesPerAccent: Object.fromEntries([...perAccent.entries()].sort(([a], [b]) => a.localeCompare(b))),
    missingAccents,
    missingFormats,
  };
}

function checkVision(fixtures, errors) {
  checkUnique(fixtures, 'image', errors, 'vision');
  for (const fixture of fixtures) {
    const format = formatOf(fixture, 'image');
    if (!REQUIRED_IMAGE_FORMATS.includes(format)) {
      errors.push(`vision: format non supporté pour ${fixture.id} (${format || 'absent'})`);
    } else if (fixture.contentType && fixture.contentType !== IMAGE_CONTENT_TYPES[format]) {
      errors.push(
        `vision: content-type ${fixture.contentType} incohérent avec ${format} pour ${fixture.id}`,
      );
    }
    if (!('expectedMetier' in fixture)) {
      errors.push(`vision: attendu manquant pour ${fixture.id}`);
    }
  }
  const formats = [...new Set(fixtures.map((fixture) => formatOf(fixture, 'image')))].sort();
  const missingFormats = REQUIRED_IMAGE_FORMATS.filter((format) => !formats.includes(format));
  if (missingFormats.length) errors.push(`formats image manquants: ${missingFormats.join(', ')}`);
  const ambiguous = fixtures.filter((fixture) => fixture.expectedMetier === null).length;
  if (!ambiguous) errors.push('vision: aucun cas ambigu pour mesurer les hallucinations');
  return { cases: fixtures.length, formats, missingFormats, ambiguousCases: ambiguous };
}

const errors = [];
const transcription = checkTranscription(readJsonl(transcriptionPath), errors);
const vision = checkVision(readJsonl(visionPath), errors);

const report = {
  transcription,
  vision,
  errors,
  complete: errors.length === 0,
};

const outputPath = path.join('build', 'quality', 'ai-eval-corpus-report.json');
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));

// Le corpus est versionné : toute violation est un défaut, pas un reste à
// faire. Le contrôle échoue donc sans option supplémentaire.
if (errors.length) {
  console.error(`Couverture du corpus IA insuffisante: ${errors.join(' | ')}`);
  process.exitCode = 1;
}
