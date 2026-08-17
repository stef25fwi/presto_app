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
assert.ok(
  source.includes(".select('category', 'categoryId', 'city', 'cityId', 'postalCode', 'cp', 'title', 'description', 'publishedAt', 'createdAt')"),
  'Projection SEO minimale du collecteur absente',
);
assert.ok(source.includes('const SAFE_PUBLIC_ID = /^[A-Za-z0-9_-]{6,128}$/;'), 'Validation identifiant public absente');
assert.ok(source.includes('title.length >= 12'), 'Seuil qualité title annonce absent');
assert.ok(source.includes('description.length >= 80'), 'Seuil qualité description annonce absent');
assert.ok(source.includes('listingPreviews: []'), 'Prévisualisations annonces locales absentes');
assert.ok(source.includes('MAX_PREVIEWS_PER_PAGE = 5'), 'Limite des prévisualisations absente');
assert.ok(source.includes('seoQualifiedPublicListings'), 'Compteur annonces SEO qualifiées absent');
assert.ok(!source.includes("'phone'"), 'Téléphone interdit dans la projection SEO locale');
assert.ok(!source.includes("'email'"), 'Email interdit dans la projection SEO locale');
assert.ok(!source.includes("'ownerId'"), 'ownerId interdit dans la projection SEO locale');
assert.ok(source.includes("source: 'production-marketplace-aggregate-unavailable'"), 'Fail-safe noindex absent');
assert.ok(
  source.includes("const allowFallback = hasFlag('--allow-fallback') && !hasFlag('--strict');"),
  'Le collecteur doit être strict par défaut et n’autoriser le fallback que via --allow-fallback',
);
assert.ok(!source.includes("const safeFallback = !hasFlag('--strict')"), 'Le fallback implicite par défaut est interdit');
assert.ok(source.includes('if (!allowFallback) throw error;'), 'Une erreur Firestore doit faire échouer le collecteur par défaut');

console.log('Collecteur de signaux SEO production: annonces publiques qualifiées, projection sans PII, API Admin modulaire et mode strict validés.');
