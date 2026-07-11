import assert from 'node:assert/strict';
import test from 'node:test';

import { auditAppCheckSource } from './check_functions_app_check.mjs';

test('accepte un callable protégé par la policy centrale', () => {
  const result = auditAppCheckSource(`
    export const secure = onCall(
      {
        region: PROJECT_REGION,
        enforceAppCheck: ENFORCE_APP_CHECK,
      },
      async () => ({ ok: true }),
    );
  `);
  assert.equal(result.callableCount, 1);
  assert.deepEqual(result.violations, []);
});

test('refuse un callable sans option App Check', () => {
  const result = auditAppCheckSource(`
    export const insecure = onCall(
      { region: PROJECT_REGION },
      async () => ({ ok: true }),
    );
  `, 'insecure.ts');
  assert.equal(result.violations.length, 1);
  assert.equal(result.violations[0].type, 'missing-enforcement');
  assert.equal(result.violations[0].file, 'insecure.ts');
});

test('refuse une désactivation explicite', () => {
  const result = auditAppCheckSource(`
    export const disabled = onCall(
      { enforceAppCheck: false },
      async () => ({ ok: true }),
    );
  `);
  assert.deepEqual(
    result.violations.map((violation) => violation.type).sort(),
    ['explicit-disable', 'missing-enforcement'],
  );
});

test('ne traite pas onRequest comme un callable App Check', () => {
  const result = auditAppCheckSource(`
    export const webhook = onRequest(async (_request, response) => {
      response.sendStatus(204);
    });
  `);
  assert.equal(result.callableCount, 0);
  assert.deepEqual(result.violations, []);
});
