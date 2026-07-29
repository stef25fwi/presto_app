import assert from 'node:assert/strict';
import test from 'node:test';

import {
  BLOCKING_SEVERITIES,
  blockingFindings,
  renderMarkdown,
  summarize,
} from './generate_dependency_audit.mjs';

test('summarize trie les vulnérabilités par sévérité décroissante', () => {
  const { counts, vulnerabilities } = summarize({
    metadata: { vulnerabilities: { critical: 0, high: 1, moderate: 1, low: 0 } },
    vulnerabilities: {
      alpha: { severity: 'moderate', effects: [] },
      beta: { severity: 'high', effects: ['alpha'] },
    },
  });

  assert.equal(counts.high, 1);
  assert.deepEqual(vulnerabilities.map(([name]) => name), ['beta', 'alpha']);
});

test('summarize départage les sévérités égales par ordre alphabétique', () => {
  const { vulnerabilities } = summarize({
    metadata: { vulnerabilities: {} },
    vulnerabilities: {
      zeta: { severity: 'high' },
      alpha: { severity: 'high' },
    },
  });

  assert.deepEqual(vulnerabilities.map(([name]) => name), ['alpha', 'zeta']);
});

test('summarize tolère un rapport npm audit sans vulnérabilité', () => {
  const { counts, vulnerabilities } = summarize({});
  assert.deepEqual(counts, {});
  assert.deepEqual(vulnerabilities, []);
});

test('renderMarkdown annonce explicitement un espace sain', () => {
  const markdown = renderMarkdown([
    { id: 'racine', counts: { critical: 0, high: 0, moderate: 0, low: 0 }, vulnerabilities: [] },
  ]);

  assert.match(markdown, /## Espace `racine`/);
  assert.match(markdown, /Aucune vulnérabilité connue\./);
  assert.doesNotMatch(markdown, /\| Module \|/);
});

test('renderMarkdown tabule les vulnérabilités et leurs effets', () => {
  const markdown = renderMarkdown([
    {
      id: 'functions',
      counts: { critical: 0, high: 1, moderate: 0, low: 0 },
      vulnerabilities: [
        ['brace-expansion', { severity: 'high', isDirect: false, fixAvailable: true, effects: ['minimatch'] }],
      ],
    },
  ]);

  assert.match(markdown, /Hautes : \*\*1\*\*/);
  assert.match(markdown, /\| brace-expansion \| high \| non \| oui \| minimatch \|/);
});

test('blockingFindings ne retient que les sévérités critiques et hautes', () => {
  const findings = blockingFindings([
    { id: 'racine', counts: { critical: 0, high: 0, moderate: 4, low: 2 } },
    { id: 'functions', counts: { critical: 1, high: 2, moderate: 0, low: 0 } },
  ]);

  assert.deepEqual(findings, ['functions:critical=1', 'functions:high=2']);
});

test('blockingFindings est vide quand aucun espace ne dépasse le seuil', () => {
  assert.deepEqual(
    blockingFindings([{ id: 'racine', counts: { critical: 0, high: 0 } }]),
    [],
  );
  assert.deepEqual(BLOCKING_SEVERITIES, ['critical', 'high']);
});
