import assert from 'node:assert/strict';
import test from 'node:test';

import {
  auditAppCheckSource,
  isExpiredException,
} from './check_functions_app_check.mjs';

const MESSAGING_CALLABLES = 'functions/src/modules/messaging/callables.ts';
const DISABLED_CALLABLE = `
  export const legacy = onCall(
    { enforceAppCheck: false },
    async () => ({ ok: true }),
  );
`;

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

test('borne l exception legacy de la messagerie à un seul fichier', () => {
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
  assert.deepEqual(result.violations, []);
  assert.equal(result.exceptions.length, 1);
  assert.equal(
    result.exceptions[0].id,
    'messaging-app-check-web-availability',
  );
  assert.equal(result.exceptions[0].reviewBy, '2026-08-31');

  const otherFile = auditAppCheckSource(
    source,
    'functions/src/modules/other/callables.ts',
  );
  assert.deepEqual(
    otherFile.violations.map((violation) => violation.type).sort(),
    ['explicit-disable', 'missing-enforcement', 'missing-enforcement', 'missing-enforcement'],
  );
  assert.deepEqual(otherFile.exceptions, []);
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

test('refuse une désactivation explicite hors exception', () => {
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

test('isExpiredException tolère une exception sans échéance', () => {
  assert.equal(isExpiredException({ id: 'x' }), false);
  assert.equal(isExpiredException(null), false);
});

test('isExpiredException accepte une échéance jusqu à la fin du jour dit', () => {
  const exception = { id: 'x', reviewBy: '2026-08-31' };
  assert.equal(isExpiredException(exception, new Date('2026-08-31T23:59:00Z')), false);
  assert.equal(isExpiredException(exception, new Date('2026-09-01T00:00:01Z')), true);
});

test('isExpiredException considère une échéance illisible comme périmée', () => {
  assert.equal(isExpiredException({ id: 'x', reviewBy: 'bientôt' }), true);
});

test('tolère l exception de messagerie avant son échéance', () => {
  const result = auditAppCheckSource(
    DISABLED_CALLABLE,
    MESSAGING_CALLABLES,
    new Date('2026-07-29T00:00:00Z'),
  );
  assert.deepEqual(result.violations, []);
  assert.equal(result.exceptions.length, 1);
  assert.equal(result.exceptions[0].id, 'messaging-app-check-web-availability');
});

test('refuse l exception de messagerie une fois son échéance dépassée', () => {
  const result = auditAppCheckSource(
    DISABLED_CALLABLE,
    MESSAGING_CALLABLES,
    new Date('2026-09-01T00:00:00Z'),
  );
  assert.deepEqual(result.exceptions, []);
  assert.deepEqual(
    result.violations.map((violation) => violation.type).sort(),
    ['expired-exception', 'missing-enforcement'],
  );
  assert.match(result.violations[0].message, /expired on 2026-08-31/);
});
