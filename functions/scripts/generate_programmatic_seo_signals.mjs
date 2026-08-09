#!/usr/bin/env node

import fs from 'node:fs';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const registryPath = 'web/programmatic-seo-registry.json';
const defaultOutput = 'quality/seo-programmatic-local-signals.json';

function argValue(prefix, fallback = '') {
  const item = process.argv.slice(2).find((arg) => arg.startsWith(prefix));
  return item ? item.slice(prefix.length).trim() : fallback;
}

function hasFlag(flag) {
  return process.argv.slice(2).includes(flag);
}

function normalize(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[’]/g, "'")
    .replace(/[^a-z0-9']+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function timestampMs(value) {
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(String(value || ''));
  return Number.isNaN(parsed) ? 0 : parsed;
}

const projectId = argValue('--project=', process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || '');
const outputPath = argValue('--output=', defaultOutput);
const safeFallback = !hasFlag('--strict');
const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8'));
const recentCutoff = Date.now() - Number(registry.activationGate.recentWindowDays || 90) * 24 * 60 * 60 * 1000;

function emptyPages() {
  const pages = {};
  for (const intent of registry.intents) {
    for (const service of registry.services) {
      for (const city of registry.cities) {
        pages[`${intent.key}:${service.key}:${city.slug}`] = {
          activeListings: 0,
          recentListings: 0,
          qualifiedProfiles: 0,
          recentProfiles: 0,
        };
      }
    }
  }
  return pages;
}

function writeReport(report) {
  fs.mkdirSync('quality', {recursive: true});
  fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
}

try {
  const app = getApps().length > 0
    ? getApps()[0]
    : initializeApp(projectId ? {projectId} : undefined);
  const db = getFirestore(app);
  const query = db.collection('listings')
    .where('status', '==', 'active')
    .where('visibility', '==', 'public')
    .select('category', 'categoryId', 'city', 'cityId', 'postalCode', 'cp', 'publishedAt', 'createdAt');

  const snapshot = await query.get();
  const counts = new Map();

  for (const service of registry.services) {
    for (const city of registry.cities) {
      counts.set(`${service.key}:${city.slug}`, {activeListings: 0, recentListings: 0});
    }
  }

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const categoryKeys = new Set([
      normalize(data.category),
      normalize(data.categoryId),
    ].filter(Boolean));
    const postalCode = String(data.postalCode || data.cp || '').trim();
    const cityKeys = new Set([
      normalize(data.city),
      normalize(data.cityId),
    ].filter(Boolean));

    const service = registry.services.find((candidate) => {
      const expected = new Set([
        normalize(candidate.taxonomyValue),
        normalize(candidate.key),
        normalize(candidate.slug),
        ...candidate.keywords.map(normalize),
      ]);
      return [...categoryKeys].some((value) => expected.has(value));
    });
    if (!service) continue;

    const city = registry.cities.find((candidate) => {
      if (postalCode && postalCode === candidate.postalCode) return true;
      const expected = new Set([normalize(candidate.name), normalize(candidate.slug)]);
      return [...cityKeys].some((value) => expected.has(value) || value.endsWith(`-${normalize(candidate.slug)}`));
    });
    if (!city) continue;

    const key = `${service.key}:${city.slug}`;
    const bucket = counts.get(key);
    if (!bucket) continue;
    bucket.activeListings += 1;
    const publicationMs = timestampMs(data.publishedAt) || timestampMs(data.createdAt);
    if (publicationMs >= recentCutoff) bucket.recentListings += 1;
  }

  const pages = {};
  for (const intent of registry.intents) {
    for (const service of registry.services) {
      for (const city of registry.cities) {
        const bucket = counts.get(`${service.key}:${city.slug}`) || {activeListings: 0, recentListings: 0};
        pages[`${intent.key}:${service.key}:${city.slug}`] = {
          activeListings: bucket.activeListings,
          recentListings: bucket.recentListings,
          qualifiedProfiles: 0,
          recentProfiles: 0,
        };
      }
    }
  }

  writeReport({
    version: 1,
    generatedAt: new Date().toISOString(),
    source: 'production-marketplace-aggregate',
    projectId: projectId || null,
    scannedPublicActiveListings: snapshot.size,
    recentWindowDays: Number(registry.activationGate.recentWindowDays || 90),
    pages,
  });
  console.log(`SEO local signals: ${snapshot.size} annonces publiques actives analysées; sortie ${outputPath}.`);
} catch (error) {
  if (!safeFallback) throw error;
  writeReport({
    version: 1,
    generatedAt: null,
    source: 'production-marketplace-aggregate-unavailable',
    projectId: projectId || null,
    scannedPublicActiveListings: 0,
    recentWindowDays: Number(registry.activationGate.recentWindowDays || 90),
    pages: emptyPages(),
    fallbackReason: String(error?.message || error || 'unknown'),
  });
  console.warn(`SEO local signals indisponibles: fallback noindex appliqué (${String(error?.message || error)}).`);
}
