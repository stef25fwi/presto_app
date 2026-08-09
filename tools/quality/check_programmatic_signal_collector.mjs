import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync('functions/scripts/generate_programmatic_seo_signals.mjs', 'utf8');

assert.ok(
  source.includes("import { getApps, initializeApp } from 'firebase-admin/app';"),
  'Le collecteur SEO doit utiliser les API modulaires firebase-admin/app',
);
assert.ok(
  source.includes("import { getFirestore } from 'firebase-admin/firestore';"),
  'Le collecteur SEO doit utiliser getFirestore modulaire',
);
assert.ok(!source.includes("import admin from 'firebase-admin'"), 'Import firebase-admin legacy interdit');
assert.ok(!source.includes('admin.apps.length'), 'Accès admin.apps legacy interdit');
assert.ok(source.includes(".where('status', '==', 'active')"), 'Filtre annonces actives absent');
assert.ok(source.includes(".where('visibility', '==', 'public')"), 'Filtre annonces publiques absent');
assert.ok(source.includes(".select('category', 'categoryId', 'city', 'cityId', 'postalCode', 'cp', 'publishedAt', 'createdAt')"), 'Projection minimale du collecteur absente');
assert.ok(source.includes("source: 'production-marketplace-aggregate-unavailable'"), 'Fail-safe noindex absent');

console.log('Collecteur de signaux SEO production: API Admin modulaire et garde-fous validés.');
