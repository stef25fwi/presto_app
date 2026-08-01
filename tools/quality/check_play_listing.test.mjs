import assert from 'node:assert/strict';
import test from 'node:test';

import { LIMITS, checkSections, extractSections } from './check_play_listing.mjs';

const markdown = `# Fiche

## Titre (30 caractères max)

\`\`\`
iliprestō — services locaux
\`\`\`

Commentaire ignoré.

## Description courte (80 caractères max)

\`\`\`
Annonces de services locaux, mise en relation directe, 0 % de commission.
\`\`\`

## Description longue (4 000 caractères max)

\`\`\`
Première ligne.

Seconde ligne.
\`\`\`
`;

test('extrait le premier bloc de code de chaque section', () => {
  const sections = extractSections(markdown);
  assert.equal(sections.title, 'iliprestō — services locaux');
  assert.match(sections.shortDescription, /^Annonces de services locaux/);
  assert.equal(sections.longDescription, 'Première ligne.\n\nSeconde ligne.');
});

test('accepte des textes dans les limites', () => {
  const findings = checkSections(extractSections(markdown));
  assert.deepEqual(
    findings.map((finding) => finding.status),
    ['ok', 'ok', 'ok']
  );
});

test('compte les caractères et non les octets', () => {
  // « iliprestō » vaut 9 caractères mais 10 octets en UTF-8 : compter les
  // octets rejetterait à tort un titre valide.
  const findings = checkSections({
    title: 'iliprestō',
    shortDescription: 'court',
    longDescription: 'long'
  });
  assert.equal(findings[0].length, 9);
  assert.equal(findings[0].status, 'ok');
});

test('signale un titre trop long', () => {
  const findings = checkSections({
    title: 'x'.repeat(LIMITS.title + 1),
    shortDescription: 'court',
    longDescription: 'long'
  });
  assert.equal(findings[0].status, 'too_long');
  assert.equal(findings[0].length, LIMITS.title + 1);
});

test('signale une section absente', () => {
  const findings = checkSections({});
  assert.deepEqual(
    findings.map((finding) => finding.status),
    ['missing', 'missing', 'missing']
  );
});
