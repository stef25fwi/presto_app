#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

import {
  corpusCoverage,
  evaluateGates,
} from '../../functions/scripts/openai_transcription_eval.mjs';

const repoRoot = path.resolve(import.meta.dirname, '..', '..');
const checker = path.join(repoRoot, 'tools', 'quality', 'check_ai_eval_corpus.mjs');
const transcriptionSource = path.join(
  repoRoot,
  'functions',
  'evals',
  'transcription_cases.jsonl',
);
const visionSource = path.join(repoRoot, 'functions', 'evals', 'vision_cases.jsonl');

function readJsonl(filePath) {
  return fs
    .readFileSync(filePath, 'utf8')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

function runInFixture(transcription, vision) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-eval-corpus-'));
  const evalsDirectory = path.join(temp, 'functions', 'evals');
  fs.mkdirSync(evalsDirectory, { recursive: true });
  fs.writeFileSync(
    path.join(evalsDirectory, 'transcription_cases.jsonl'),
    `${transcription.map((item) => JSON.stringify(item)).join('\n')}\n`,
  );
  fs.writeFileSync(
    path.join(evalsDirectory, 'vision_cases.jsonl'),
    `${vision.map((item) => JSON.stringify(item)).join('\n')}\n`,
  );
  return spawnSync(process.execPath, [checker], { cwd: temp, encoding: 'utf8' });
}

const baseTranscription = readJsonl(transcriptionSource);
const baseVision = readJsonl(visionSource);

// Le corpus versionné doit passer tel quel.
const nominal = runInFixture(baseTranscription, baseVision);
assert.equal(nominal.status, 0, nominal.stderr);
assert.match(nominal.stdout, /"complete": true/);

// Retirer le seul cas WebM doit bloquer : le conteneur est accepté en production.
const withoutWebm = baseTranscription.filter((item) => item.format !== 'webm');
const missingFormat = runInFixture(withoutWebm, baseVision);
assert.notEqual(missingFormat.status, 0);
assert.match(missingFormat.stderr, /formats audio manquants: webm/);

// Un corpus réduit à un seul accent ne prouve rien.
const singleAccent = baseTranscription.filter((item) => item.accent === 'fr-FR');
const missingAccents = runInFixture(singleAccent, baseVision);
assert.notEqual(missingAccents.status, 0);
assert.match(missingAccents.stderr, /accents manquants: fr-BE, fr-CH/);

// Un identifiant dupliqué fausserait les moyennes par groupe.
const duplicated = structuredClone(baseTranscription);
duplicated[1].id = duplicated[0].id;
const duplicateRun = runInFixture(duplicated, baseVision);
assert.notEqual(duplicateRun.status, 0);
assert.match(duplicateRun.stderr, /identifiant dupliqué/);

// Le type MIME déclaré doit correspondre au conteneur réellement produit.
const wrongMime = structuredClone(baseTranscription);
wrongMime[0].contentType = 'audio/mpeg';
const wrongMimeRun = runInFixture(wrongMime, baseVision);
assert.notEqual(wrongMimeRun.status, 0);
assert.match(wrongMimeRun.stderr, /content-type audio\/mpeg incohérent avec wav/);

// La classification photo accepte jpeg, png et webp.
const visionWithoutWebp = baseVision.filter((item) => item.format !== 'webp');
const visionRun = runInFixture(baseTranscription, visionWithoutWebp);
assert.notEqual(visionRun.status, 0);
assert.match(visionRun.stderr, /formats image manquants: webp/);

// Sans cas ambigu, le taux d'hallucination n'est pas mesurable.
const visionWithoutAmbiguous = baseVision.filter((item) => item.expectedMetier !== null);
const ambiguousRun = runInFixture(baseTranscription, visionWithoutAmbiguous);
assert.notEqual(ambiguousRun.status, 0);
assert.match(ambiguousRun.stderr, /aucun cas ambigu/);

// La couverture calculée par le harnais doit rester alignée sur le corpus.
const coverage = corpusCoverage(baseTranscription);
assert.deepEqual(coverage.missingAccents, []);
assert.deepEqual(coverage.missingFormats, []);

const limits = {
  maxWer: 0.35,
  maxEntityErrorRate: 0.2,
  maxHallucinationRate: 0.25,
  maxP95Ms: 60_000,
  maxGroupWer: 0.45,
  maxGroupEntityErrorRate: 0.34,
};

const healthy = {
  averageWer: 0.1,
  averageEntityErrorRate: 0.05,
  averageHallucinationExtraWordRate: 0.05,
  latencyMs: { p95: 4_000 },
  coverage,
  byAccent: { 'fr-FR': { averageWer: 0.1, averageEntityErrorRate: 0.05 } },
  byFormat: { wav: { averageWer: 0.12, averageEntityErrorRate: 0.05 } },
};
assert.deepEqual(evaluateGates(healthy, limits), []);

// Une moyenne globale correcte ne doit pas masquer un accent dégradé.
const degradedAccent = structuredClone(healthy);
degradedAccent.byAccent['fr-CH'] = { averageWer: 0.6, averageEntityErrorRate: 0.05 };
const accentFailures = evaluateGates(degradedAccent, limits);
assert.equal(accentFailures.length, 1);
assert.match(accentFailures[0], /accent fr-CH: WER 0\.6 > 0\.45/);

// Idem pour un conteneur audio dont les entités se perdent.
const degradedFormat = structuredClone(healthy);
degradedFormat.byFormat.webm = { averageWer: 0.2, averageEntityErrorRate: 0.5 };
const formatFailures = evaluateGates(degradedFormat, limits);
assert.equal(formatFailures.length, 1);
assert.match(formatFailures[0], /format webm: entity error 0\.5 > 0\.34/);

// Une couverture incomplète est un échec de gate, pas une simple statistique.
const partialCoverage = structuredClone(healthy);
partialCoverage.coverage = {
  accents: ['fr-FR'],
  formats: ['wav'],
  missingAccents: ['fr-BE', 'fr-CH'],
  missingFormats: ['mp3'],
};
const coverageFailures = evaluateGates(partialCoverage, limits);
assert.match(coverageFailures.join(' | '), /accents manquants: fr-BE, fr-CH/);
assert.match(coverageFailures.join(' | '), /formats manquants: mp3/);

console.log('AI evaluation corpus checker tests passed.');
