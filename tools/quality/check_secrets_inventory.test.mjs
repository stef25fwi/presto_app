import assert from 'node:assert/strict';
import test from 'node:test';

import {
  compareInventory,
  extractDeclaredSecrets,
} from './check_secrets_inventory.mjs';

const ENTRY = { name: 'STRIPE_SECRET_KEY', owner: 'billing', purpose: 'Stripe.' };

test('extractDeclaredSecrets relève les appels defineSecret sur tous les quotes', () => {
  const source = `
    export const A = defineSecret("OPENAI_API_KEY");
    export const B = defineSecret('BREVO_API_KEY');
    export const C = defineSecret(\`VEO_API_KEY\`);
  `;
  assert.deepEqual(extractDeclaredSecrets(source), [
    'OPENAI_API_KEY',
    'BREVO_API_KEY',
    'VEO_API_KEY',
  ]);
});

test('extractDeclaredSecrets ignore une mention en commentaire', () => {
  const source = '// VEO_API_KEY intentionally NOT defined here\nconst x = 1;';
  assert.deepEqual(extractDeclaredSecrets(source), []);
});

test('accepte un inventaire exactement aligné sur la source', () => {
  const report = compareInventory(['STRIPE_SECRET_KEY'], { secrets: [ENTRY] });
  assert.equal(report.ready, true);
  assert.deepEqual(report.failures, []);
  assert.equal(report.declaredCount, 1);
  assert.equal(report.inventoriedCount, 1);
});

test('refuse un secret déclaré dans le code mais absent de l inventaire', () => {
  const report = compareInventory(['STRIPE_SECRET_KEY', 'NOUVEAU_SECRET'], {
    secrets: [ENTRY],
  });
  assert.equal(report.ready, false);
  assert.deepEqual(report.failures, ['secret-non-inventorie:NOUVEAU_SECRET']);
});

test('refuse une entrée d inventaire devenue orpheline', () => {
  const report = compareInventory([], { secrets: [ENTRY] });
  assert.equal(report.ready, false);
  assert.deepEqual(report.failures, ['entree-orpheline:STRIPE_SECRET_KEY']);
});

test('refuse une entrée sans gouvernance déclarée', () => {
  const report = compareInventory(['STRIPE_SECRET_KEY'], {
    secrets: [{ name: 'STRIPE_SECRET_KEY' }],
  });
  assert.equal(report.ready, false);
  assert.deepEqual(report.failures, [
    'champ-manquant:STRIPE_SECRET_KEY.owner',
    'champ-manquant:STRIPE_SECRET_KEY.purpose',
  ]);
});

test('refuse un doublon d inventaire', () => {
  const report = compareInventory(['STRIPE_SECRET_KEY'], {
    secrets: [ENTRY, ENTRY],
  });
  assert.equal(report.ready, false);
  assert.deepEqual(report.failures, ['doublon-inventaire:STRIPE_SECRET_KEY']);
});

test('compte un secret déclaré plusieurs fois une seule fois', () => {
  const report = compareInventory(
    ['STRIPE_SECRET_KEY', 'STRIPE_SECRET_KEY'],
    { secrets: [ENTRY] },
  );
  assert.equal(report.ready, true);
  assert.equal(report.declaredCount, 1);
});

test('tolère un inventaire sans clé secrets', () => {
  const report = compareInventory([], {});
  assert.equal(report.ready, true);
  assert.equal(report.inventoriedCount, 0);
});
