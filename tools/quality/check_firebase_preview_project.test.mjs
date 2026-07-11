import assert from 'node:assert/strict';
import test from 'node:test';

import { evaluatePreviewProject } from './check_firebase_preview_project.mjs';

test('désactive la preview sans identifiant de projet', () => {
  assert.deepEqual(evaluatePreviewProject(''), {
    enabled: false,
    reason: 'missing-project-id',
    message: 'Firebase preview skipped: FIREBASE_PROJECT_ID is missing.',
  });
});

test('refuse explicitement le projet Firebase production', () => {
  const result = evaluatePreviewProject(' presto-app-74abe ');
  assert.equal(result.enabled, false);
  assert.equal(result.reason, 'production-project-forbidden');
  assert.match(result.message, /production project/);
});

test('autorise un projet staging distinct', () => {
  assert.deepEqual(evaluatePreviewProject('presto-app-staging'), {
    enabled: true,
    reason: 'safe-preview-project',
    message: 'Firebase preview project accepted: presto-app-staging.',
  });
});
