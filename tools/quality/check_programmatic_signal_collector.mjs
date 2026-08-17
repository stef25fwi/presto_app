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
assert.ok(
  source.includes("const allowFallback = hasFlag('--allow-fallback') && !hasFlag('--strict');"),
  'Le collecteur doit être strict par défaut et n’autoriser le fallback que via --allow-fallback',
);
assert.ok(!source.includes("const safeFallback = !hasFlag('--strict')"), 'Le fallback implicite par défaut est interdit');
assert.ok(source.includes('if (!allowFallback) throw error;'), 'Une erreur Firestore doit faire échouer le collecteur par défaut');

console.log('Collecteur de signaux SEO production: API Admin modulaire, mode strict par défaut et garde-fous validés.');
