import assert from 'node:assert/strict';
import test from 'node:test';

import { evaluateStagingReadiness } from './check_firebase_staging_readiness.mjs';

test('refuse un staging sans secrets', () => {
  const result = evaluateStagingReadiness({ projectId: '', token: '' });
  assert.equal(result.ready, false);
  assert.deepEqual(result.issues, ['missing-project-id', 'missing-staging-token']);
});

test('refuse le projet production même avec un token', () => {
  const result = evaluateStagingReadiness({
    projectId: 'presto-app-74abe',
    token: 'token',
  });
  assert.equal(result.ready, false);
  assert.deepEqual(result.issues, ['production-project-forbidden']);
});

test('accepte un projet staging distinct avec token', () => {
  const result = evaluateStagingReadiness({
    projectId: 'presto-app-staging',
    token: 'token',
  });
  assert.equal(result.ready, true);
  assert.deepEqual(result.issues, []);
});
