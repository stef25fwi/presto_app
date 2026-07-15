import assert from 'node:assert/strict';
import test from 'node:test';

import { evaluatePreviewProject } from './check_firebase_preview_project.mjs';

test('désactive la preview sans identifiant staging', () => {
  assert.deepEqual(evaluatePreviewProject(''), {
    enabled: false,
    reason: 'missing-project-id',
    message:
      'Firebase preview skipped: FIREBASE_STAGING_PROJECT_ID is missing.',
  });
});

test('refuse explicitement le projet Firebase production connu', () => {
  const result = evaluatePreviewProject(' PRESTO-APP-74ABE ');
  assert.equal(result.enabled, false);
  assert.equal(result.reason, 'production-project-forbidden');
});

test('refuse aussi le projet production fourni par secret', () => {
  const result = evaluatePreviewProject(
    'ilipresto-staging',
    'ilipresto-staging',
  );
  assert.equal(result.enabled, false);
  assert.equal(result.reason, 'production-project-forbidden');
});

test('refuse une URL ou un hostname à la place du project ID', () => {
  const result = evaluatePreviewProject('https://presto-app-staging.web.app');
  assert.equal(result.enabled, false);
  assert.equal(result.reason, 'invalid-project-id');
});

test('refuse un projet non-production mais ambigu', () => {
  const result = evaluatePreviewProject('presto-app-sandbox');
  assert.equal(result.enabled, false);
  assert.equal(result.reason, 'ambiguous-preview-project');
});

test('autorise un projet staging distinct', () => {
  assert.deepEqual(evaluatePreviewProject('presto-app-staging'), {
    enabled: true,
    reason: 'safe-preview-project',
    message: 'Firebase preview project accepted: presto-app-staging.',
  });
});

test('autorise les marqueurs preview, dev, test et qa', () => {
  for (const projectId of [
    'presto-app-preview',
    'presto-app-dev',
    'presto-app-test',
    'presto-app-qa',
  ]) {
    assert.equal(evaluatePreviewProject(projectId).enabled, true, projectId);
  }
});

test('n accepte pas un marqueur seulement inclus dans un autre segment', () => {
  const result = evaluatePreviewProject('presto-app-contest');
  assert.equal(result.enabled, false);
  assert.equal(result.reason, 'ambiguous-preview-project');
});
