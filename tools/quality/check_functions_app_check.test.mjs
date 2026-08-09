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
  assert.deepEqual(result.exceptions, []);
});

test('accepte une activation App Check stricte codée à true', () => {
  const result = auditAppCheckSource(`
    export const secure = onCall(
      { region: PROJECT_REGION, enforceAppCheck: true },
      async () => ({ ok: true }),
    );
  `);
  assert.deepEqual(result.violations, []);
  assert.deepEqual(result.exceptions, []);
});

test('accepte des constantes d options sûres et leurs extensions', () => {
  const result = auditAppCheckSource(`
    const BASE_OPTIONS = {
      region: PROJECT_REGION,
      enforceAppCheck: ENFORCE_APP_CHECK,
    } as const;
    const HOT_OPTIONS = {
      ...BASE_OPTIONS,
      minInstances: 1,
    } as const;
    export const first = onCall(BASE_OPTIONS, async () => ({ ok: true }));
    export const second = onCall(HOT_OPTIONS, async () => ({ ok: true }));
    export const third = onCall(
      { ...HOT_OPTIONS, timeoutSeconds: 60 },
      async () => ({ ok: true }),
    );
  `);
  assert.equal(result.callableCount, 3);
  assert.deepEqual(result.violations, []);
  assert.deepEqual(result.exceptions, []);
});

test('refuse aussi une désactivation explicite dans la messagerie', () => {
  const source = `
    const MESSAGING_CALLABLE_OPTIONS = {
      region: PROJECT_REGION,
      enforceAppCheck: false,
    } as const;
    const HOT_MESSAGING_CALLABLE_OPTIONS = {
      ...MESSAGING_CALLABLE_OPTIONS,
      minInstances: 1,
    } as const;
    export const first = onCall(
      MESSAGING_CALLABLE_OPTIONS,
      async () => ({ ok: true }),
    );
    export const second = onCall(
      HOT_MESSAGING_CALLABLE_OPTIONS,
      async () => ({ ok: true }),
    );
    export const third = onCall(
      { ...HOT_MESSAGING_CALLABLE_OPTIONS, timeoutSeconds: 60 },
      async () => ({ ok: true }),
    );
  `;
  const result = auditAppCheckSource(
    source,
    'functions/src/modules/messaging/callables.ts',
  );
  assert.equal(result.callableCount, 3);
  assert.deepEqual(
    result.violations.map((violation) => violation.type).sort(),
    ['explicit-disable', 'missing-enforcement', 'missing-enforcement', 'missing-enforcement'],
  );
  assert.deepEqual(result.exceptions, []);
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

test('refuse une constante d options qui ne propage pas la policy', () => {
  const result = auditAppCheckSource(`
    const OPTIONS = { region: PROJECT_REGION } as const;
    export const insecure = onCall(OPTIONS, async () => ({ ok: true }));
  `);
  assert.equal(result.violations.length, 1);
  assert.equal(result.violations[0].type, 'missing-enforcement');
});

test('refuse une désactivation explicite', () => {
  const result = auditAppCheckSource(`
    export const disabled = onCall(
      { enforceAppCheck: false },
      async () => ({ ok: true }),
    );
  `, 'functions/src/modules/other/callables.ts');
  assert.deepEqual(
    result.violations.map((violation) => violation.type).sort(),
    ['explicit-disable', 'missing-enforcement'],
  );
  assert.deepEqual(result.exceptions, []);
});

test('ne traite pas onRequest comme un callable App Check', () => {
  const result = auditAppCheckSource(`
    export const webhook = onRequest(async (_request, response) => {
      response.sendStatus(204);
    });
  `);
  assert.equal(result.callableCount, 0);
  assert.deepEqual(result.violations, []);
  assert.deepEqual(result.exceptions, []);
});
