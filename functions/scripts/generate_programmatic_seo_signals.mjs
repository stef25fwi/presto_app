#!/usr/bin/env node

import fs from 'node:fs';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const registryPath = 'web/programmatic-seo-registry.json';
const defaultOutput = 'quality/seo-programmatic-local-signals.json';
const SAFE_PUBLIC_ID = /^[A-Za-z0-9_-]{6,128}$/;
const MAX_PREVIEWS_PER_PAGE = 5;
const MAX_PROFILE_PREVIEWS_PER_PAGE = 5;

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

function timestampIso(value) {
  const ms = timestampMs(value);
  return ms > 0 ? new Date(ms).toISOString() : null;
}

function boundedText(value, maxLength) {
  return String(value || '')
    .replace(/[\u0000-\u001F\u007F]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLength);
}

function listingContentRejectionReasons(id, data) {
  const title = boundedText(data.title, 140);
  const description = boundedText(data.description, 2000);
  const reasons = [];
  if (!SAFE_PUBLIC_ID.test(String(id || ''))) reasons.push('invalid_public_id');
  if (title.length < 12) reasons.push('title_too_short');
  if (description.length < 80) reasons.push('description_too_short');
  return reasons;
}

function listingDiagnosticBase(id, data) {
  const title = boundedText(data.title, 140);
  const description = boundedText(data.description, 2000);
  return {
    id: String(id || ''),
    title,
    titleLength: title.length,
    descriptionLength: description.length,
    category: boundedText(data.category, 140),
    categoryId: boundedText(data.categoryId, 140),
    subCategory: boundedText(data.subCategory || data.subcategory, 180),
    city: boundedText(data.city, 140),
    cityId: boundedText(data.cityId, 180),
    postalCode: String(data.postalCode || data.cp || '').trim().slice(0, 16),
  };
}

function addRejection(summary, reasons) {
  for (const reason of reasons) {
    summary[reason] = Number(summary[reason] || 0) + 1;
  }
}

const projectId = argValue('--project=', process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || '');
const outputPath = argValue('--output=', defaultOutput);
// Le collecteur de production est strict par défaut : une panne Firestore doit
// faire échouer le pipeline. Le fallback noindex n'est autorisé que lorsqu'il
// est demandé explicitement pour un diagnostic/local avec --allow-fallback.
// --strict reste accepté et prend priorité pour compatibilité.
const allowFallback = hasFlag('--allow-fallback') && !hasFlag('--strict');
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
          listingPreviews: [],
          profilePreviews: [],
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
    .select('category', 'categoryId', 'subCategory', 'subcategory', 'city', 'cityId', 'postalCode', 'cp', 'title', 'description', 'publishedAt', 'createdAt');

  const snapshot = await query.get();
  const profileSnapshot = await db.collection('public_service_profiles')
    .where('visibility', '==', 'public')
    .select('companyName', 'activity', 'serviceCategories', 'city', 'postalCode', 'publishedAt', 'updatedAt', 'seoEligible', 'verified')
    .get();
  const counts = new Map();
  let seoQualifiedPublicListings = 0;
  let seoQualifiedPublicProfiles = 0;
  const listingDiagnostics = [];
  const listingRejectionSummary = {};

  for (const service of registry.services) {
    for (const city of registry.cities) {
      counts.set(`${service.key}:${city.slug}`, {
        activeListings: 0,
        recentListings: 0,
        listingPreviews: [],
        qualifiedProfiles: 0,
        recentProfiles: 0,
        profilePreviews: [],
      });
    }
  }

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const diagnostic = listingDiagnosticBase(doc.id, data);
    const contentReasons = listingContentRejectionReasons(doc.id, data);
    if (contentReasons.length > 0) {
      diagnostic.status = 'rejected';
      diagnostic.reasons = contentReasons;
      listingDiagnostics.push(diagnostic);
      addRejection(listingRejectionSummary, contentReasons);
      continue;
    }

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
    if (!service) {
      diagnostic.status = 'rejected';
      diagnostic.reasons = ['service_unmatched'];
      listingDiagnostics.push(diagnostic);
      addRejection(listingRejectionSummary, diagnostic.reasons);
      continue;
    }

    const city = registry.cities.find((candidate) => {
      const postalCodes = new Set([
        String(candidate.postalCode || '').trim(),
        ...(Array.isArray(candidate.postalCodes) ? candidate.postalCodes.map((value) => String(value).trim()) : []),
      ].filter(Boolean));
      if (postalCode && postalCodes.has(postalCode)) return true;
      const expected = new Set([normalize(candidate.name), normalize(candidate.slug)]);
      return [...cityKeys].some((value) => expected.has(value) || value.endsWith(`-${normalize(candidate.slug)}`));
    });
    if (!city) {
      diagnostic.status = 'rejected';
      diagnostic.reasons = ['city_unmatched'];
      diagnostic.matchedServiceKey = service.key;
      listingDiagnostics.push(diagnostic);
      addRejection(listingRejectionSummary, diagnostic.reasons);
      continue;
    }

    diagnostic.status = 'qualified';
    diagnostic.reasons = [];
    diagnostic.matchedServiceKey = service.key;
    diagnostic.matchedCitySlug = city.slug;
    listingDiagnostics.push(diagnostic);

    const key = `${service.key}:${city.slug}`;
    const bucket = counts.get(key);
    if (!bucket) continue;

    seoQualifiedPublicListings += 1;
    bucket.activeListings += 1;
    const publicationValue = data.publishedAt || data.createdAt;
    const publicationMs = timestampMs(publicationValue);
    if (publicationMs >= recentCutoff) bucket.recentListings += 1;
    bucket.listingPreviews.push({
      id: String(doc.id),
      title: boundedText(data.title, 140),
      publishedAt: timestampIso(publicationValue),
      publicationMs,
    });
  }


  for (const doc of profileSnapshot.docs) {
    const data = doc.data() || {};
    if (data.seoEligible !== true || data.verified !== true) continue;

    const searchable = normalize([
      boundedText(data.activity, 140),
      boundedText(data.serviceCategories, 400),
    ].filter(Boolean).join(' '));
    if (!searchable) continue;

    const services = registry.services.filter((candidate) => {
      const expected = [
        normalize(candidate.taxonomyValue),
        normalize(candidate.key),
        normalize(candidate.slug),
        ...candidate.keywords.map(normalize),
      ].filter(Boolean);
      return expected.some((value) => searchable === value || searchable.includes(value));
    });
    if (services.length === 0) continue;

    const postalCode = String(data.postalCode || '').trim();
    const cityKey = normalize(data.city);
    const city = registry.cities.find((candidate) => {
      const postalCodes = new Set([
        String(candidate.postalCode || '').trim(),
        ...(Array.isArray(candidate.postalCodes) ? candidate.postalCodes.map((value) => String(value).trim()) : []),
      ].filter(Boolean));
      if (postalCode && postalCodes.has(postalCode)) return true;
      const expected = new Set([normalize(candidate.name), normalize(candidate.slug)]);
      return cityKey && (expected.has(cityKey) || cityKey.endsWith(`-${normalize(candidate.slug)}`));
    });
    if (!city) continue;

    seoQualifiedPublicProfiles += 1;
    const publicationValue = data.updatedAt || data.publishedAt;
    const publicationMs = timestampMs(publicationValue);

    for (const service of services) {
      const bucket = counts.get(`${service.key}:${city.slug}`);
      if (!bucket) continue;

      bucket.qualifiedProfiles += 1;
      if (publicationMs >= recentCutoff) bucket.recentProfiles += 1;
      bucket.profilePreviews.push({
        publicId: String(doc.id),
        companyName: boundedText(data.companyName, 140),
        activity: boundedText(data.activity, 140),
        publishedAt: timestampIso(data.publishedAt),
        updatedAt: timestampIso(data.updatedAt),
        publicationMs,
      });
    }
  }

  for (const bucket of counts.values()) {
    bucket.listingPreviews = bucket.listingPreviews
      .sort((a, b) => b.publicationMs - a.publicationMs || a.id.localeCompare(b.id))
      .slice(0, MAX_PREVIEWS_PER_PAGE)
      .map(({id, title, publishedAt}) => ({id, title, publishedAt}));
    bucket.profilePreviews = bucket.profilePreviews
      .sort((a, b) => b.publicationMs - a.publicationMs || a.publicId.localeCompare(b.publicId))
      .slice(0, MAX_PROFILE_PREVIEWS_PER_PAGE)
      .map(({publicId, companyName, activity, publishedAt, updatedAt}) => ({
        publicId,
        companyName,
        activity,
        publishedAt,
        updatedAt,
      }));
  }

  const pages = {};
  for (const intent of registry.intents) {
    for (const service of registry.services) {
      for (const city of registry.cities) {
        const bucket = counts.get(`${service.key}:${city.slug}`) || {
          activeListings: 0,
          recentListings: 0,
          listingPreviews: [],
          qualifiedProfiles: 0,
          recentProfiles: 0,
          profilePreviews: [],
        };
        pages[`${intent.key}:${service.key}:${city.slug}`] = {
          activeListings: bucket.activeListings,
          recentListings: bucket.recentListings,
          qualifiedProfiles: bucket.qualifiedProfiles,
          recentProfiles: bucket.recentProfiles,
          listingPreviews: bucket.listingPreviews,
          profilePreviews: bucket.profilePreviews,
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
    seoQualifiedPublicListings,
    listingDiagnostics,
    listingRejectionSummary,
    scannedPublicProfiles: profileSnapshot.size,
    seoQualifiedPublicProfiles,
    recentWindowDays: Number(registry.activationGate.recentWindowDays || 90),
    pages,
  });
  console.log(`SEO local signals: ${snapshot.size} annonces publiques actives analysées, ${seoQualifiedPublicListings} annonces SEO qualifiées; ${profileSnapshot.size} profils publics analysés, ${seoQualifiedPublicProfiles} profils SEO qualifiés; sortie ${outputPath}.`);
  for (const diagnostic of listingDiagnostics.filter((item) => item.status === 'rejected')) {
    console.warn(`SEO listing rejected: ${JSON.stringify(diagnostic)}`);
  }
  if (Object.keys(listingRejectionSummary).length > 0) {
    console.warn(`SEO listing rejection summary: ${JSON.stringify(listingRejectionSummary)}`);
  }
} catch (error) {
  if (!allowFallback) throw error;
  writeReport({
    version: 1,
    generatedAt: null,
    source: 'production-marketplace-aggregate-unavailable',
    projectId: projectId || null,
    scannedPublicActiveListings: 0,
    seoQualifiedPublicListings: 0,
    listingDiagnostics: [],
    listingRejectionSummary: {},
    scannedPublicProfiles: 0,
    seoQualifiedPublicProfiles: 0,
    recentWindowDays: Number(registry.activationGate.recentWindowDays || 90),
    pages: emptyPages(),
    fallbackReason: String(error?.message || error || 'unknown'),
  });
  console.warn(`SEO local signals indisponibles: fallback noindex appliqué (${String(error?.message || error)}).`);
}
