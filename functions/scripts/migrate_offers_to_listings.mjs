#!/usr/bin/env node

import admin from 'firebase-admin';

function parseArgs(argv) {
  const opts = {
    dryRun: false,
    limit: 0,
    projectId: process.env.GCLOUD_PROJECT || '',
    onlyActive: true,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') {
      opts.dryRun = true;
      continue;
    }
    if (arg === '--all') {
      opts.onlyActive = false;
      continue;
    }
    if (arg.startsWith('--limit=')) {
      const parsed = Number(arg.slice('--limit='.length));
      if (!Number.isNaN(parsed) && parsed > 0) {
        opts.limit = Math.floor(parsed);
      }
      continue;
    }
    if (arg.startsWith('--project=')) {
      opts.projectId = arg.slice('--project='.length).trim();
    }
  }

  return opts;
}

function normalizeText(input) {
  return String(input || '')
    .trim()
    .toLowerCase()
    .replace(/[àâä]/g, 'a')
    .replace(/ç/g, 'c')
    .replace(/[éèêë]/g, 'e')
    .replace(/[îï]/g, 'i')
    .replace(/[ôö]/g, 'o')
    .replace(/[ùûü]/g, 'u')
    .replace(/œ/g, 'oe')
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function slugify(input) {
  return normalizeText(input).replace(/ /g, '-');
}

function isOfferArchivedLike(data) {
  const status = String(data.status || '').trim().toLowerCase();
  return ['archived', 'archive', 'deleted', 'removed', 'sold'].includes(status) ||
    data.archivedAt != null ||
    data.deletedAt != null;
}

function isPublicOffer(data) {
  if (isOfferArchivedLike(data)) return false;
  const status = String(data.status || '').trim().toLowerCase();
  if (status === 'active' || status === 'published') return true;
  if (data.isActive === true || data.isPublished === true) return true;
  if (data.visibility === 'public') return true;
  if (data.visibility && typeof data.visibility === 'object' && data.visibility.isPublic === true) {
    return true;
  }
  return false;
}

function budgetValueFromAny(rawBudget) {
  if (rawBudget == null) return null;
  if (typeof rawBudget === 'number' && Number.isFinite(rawBudget)) return rawBudget;
  const normalized = String(rawBudget).trim().replace(/€/g, '').replace(/\s+/g, '').replace(/,/g, '.');
  if (!normalized) return null;
  const n = Number(normalized);
  return Number.isFinite(n) ? n : null;
}

function timestampOrNull(value) {
  return value instanceof admin.firestore.Timestamp ? value : null;
}

function uniqueTokens(...values) {
  const all = values
    .flatMap((value) => normalizeText(value).split(' '))
    .map((value) => value.trim())
    .filter((value) => value.length >= 2);
  return Array.from(new Set(all)).slice(0, 80);
}

function migrateOfferToListingDoc(id, data) {
  const title = String(data.title || '').trim();
  const description = String(data.description || '').trim();
  const ownerId = String(data.ownerId || data.userId || data.uid || '').trim();
  const category = String(data.category || '').trim();
  const categoryId = String(data.categoryId || slugify(category || 'autre')).trim();
  const city = String(data.city || data.location || '').trim();
  const postalCode = String(data.postalCode || data.cp || '').trim();
  const cityId = String(data.cityId || (city && postalCode.length >= 3 ? `${postalCode}_${slugify(city)}` : '')).trim();
  const cityCategoryKey = String(data.cityCategoryKey || (cityId && categoryId ? `${cityId}_${categoryId}` : '')).trim();
  const media = Array.isArray(data.media)
    ? data.media
    : (Array.isArray(data.imageUrls)
        ? data.imageUrls.map((entry) => ({ downloadUrl: String(entry || '').trim(), thumbnailUrl: String(entry || '').trim(), storagePath: String(entry || '').trim() }))
        : []);
  const thumbnailUrl = String(data.thumbnailUrl || data.photoURL || data.imageUrl || media[0]?.thumbnailUrl || media[0]?.downloadUrl || '').trim();
  const createdAt = timestampOrNull(data.createdAt) || admin.firestore.Timestamp.now();
  const updatedAt = timestampOrNull(data.updatedAt) || createdAt;
  const publishedAt = timestampOrNull(data.publishedAt) || createdAt;
  const expiresAt = timestampOrNull(data.expiresAt);
  const budgetValue = budgetValueFromAny(data.budgetValue ?? data.budget ?? data.price);
  const price = typeof budgetValue === 'number' ? budgetValue : 0;

  return {
    id,
    ownerId,
    title,
    description,
    price,
    categoryId,
    category: category || null,
    cityId,
    city: city || null,
    location: city || null,
    postalCode: postalCode || null,
    cp: postalCode || null,
    cityCategoryKey: cityCategoryKey || null,
    dept: String(data.dept || '').trim() || null,
    region: String(data.region || '').trim() || null,
    media,
    imageUrls: Array.isArray(data.imageUrls)
      ? data.imageUrls.map((entry) => String(entry || '').trim()).filter(Boolean)
      : media.map((entry) => String(entry.downloadUrl || '').trim()).filter(Boolean),
    thumbnailUrl,
    ownerName: String(data.ownerName || data.displayName || data.userName || data.pseudo || '').trim() || null,
    displayName: String(data.displayName || data.ownerName || data.userName || data.pseudo || '').trim() || null,
    userName: String(data.userName || data.displayName || data.ownerName || data.pseudo || '').trim() || null,
    pseudo: String(data.pseudo || data.displayName || data.ownerName || data.userName || '').trim() || null,
    avatarUrl: String(data.avatarUrl || data.photoURL || '').trim() || null,
    advertiser: data.advertiser && typeof data.advertiser === 'object'
      ? data.advertiser
      : {
          id: ownerId,
          name: String(data.ownerName || data.displayName || data.userName || data.pseudo || '').trim() || 'Utilisateur',
          avatarUrl: String(data.avatarUrl || data.photoURL || '').trim() || null,
          verified: data.verified === true,
        },
    phone: String(data.phone || '').trim() || null,
    budgetType: String(data.budgetType || '').trim() || null,
    missionDelay: String(data.missionDelay || '').trim() || null,
    isUrgent: data.isUrgent === true,
    subCategory: String(data.subCategory || data.subcategory || '').trim() || null,
    status: 'active',
    moderationStatus: String(data.moderationStatus || 'approved').trim() || 'approved',
    visibility: 'public',
    mediaProcessingStatus: 'completed',
    reportCount: Number(data.reportCount || 0) || 0,
    favoriteCount: Number(data.favoriteCount || 0) || 0,
    viewCount: Number(data.viewCount || 0) || 0,
    contactCount: Number(data.contactCount || 0) || 0,
    isBoosted: data.isBoosted === true,
    boostExpiresAt: timestampOrNull(data.boostExpiresAt),
    createdAt,
    updatedAt,
    publishedAt,
    expiresAt,
    searchKeywords: Array.isArray(data.searchKeywords) && data.searchKeywords.length > 0
      ? data.searchKeywords
      : uniqueTokens(title, description, categoryId, cityId, city, postalCode),
    locationApprox: data.locationApprox && typeof data.locationApprox === 'object' ? data.locationApprox : null,
    sourceDraftId: String(data.sourceDraftId || `legacy_offer:${id}`).trim(),
    riskScore: typeof data.riskScore === 'number' ? data.riskScore : 0,
    migratedFromOfferId: id,
    migratedFromLegacyOffers: true,
    legacyOfferSnapshot: {
      status: data.status ?? null,
      visibility: data.visibility ?? null,
      isActive: data.isActive === true,
      isPublished: data.isPublished === true,
    },
  };
}

async function main() {
  const opts = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp(opts.projectId ? { projectId: opts.projectId } : {});
  }

  const db = admin.firestore();
  let query = db.collection('offers').orderBy('createdAt', 'desc');
  if (opts.onlyActive) {
    query = db.collection('offers').where('status', '==', 'active').orderBy('createdAt', 'desc');
  }
  const offersSnap = await query.get();

  let scanned = 0;
  let eligible = 0;
  let alreadyPresent = 0;
  let written = 0;
  let skipped = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of offersSnap.docs) {
    if (opts.limit > 0 && scanned >= opts.limit) break;
    scanned += 1;
    const data = doc.data() || {};
    if (!isPublicOffer(data)) {
      skipped += 1;
      continue;
    }

    const listingRef = db.collection('listings').doc(doc.id);
    const listingSnap = await listingRef.get();
    if (listingSnap.exists) {
      alreadyPresent += 1;
      continue;
    }

    eligible += 1;
    const listingDoc = migrateOfferToListingDoc(doc.id, data);
    if (opts.dryRun) {
      console.log(`[dry-run] offers/${doc.id} -> listings/${doc.id} ${listingDoc.title}`);
      continue;
    }

    batch.set(listingRef, listingDoc, { merge: true });
    batchCount += 1;
    if (batchCount >= 400) {
      await batch.commit();
      written += batchCount;
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (!opts.dryRun && batchCount > 0) {
    await batch.commit();
    written += batchCount;
  }

  console.log('--- migrate offers -> listings summary ---');
  console.log(`scanned: ${scanned}`);
  console.log(`eligible_missing_listings: ${eligible}`);
  console.log(`already_present: ${alreadyPresent}`);
  console.log(`skipped_non_public: ${skipped}`);
  console.log(`written: ${opts.dryRun ? 0 : written}`);
  console.log(`mode: ${opts.dryRun ? 'dry-run' : 'apply'}`);
}

main().catch((error) => {
  console.error('[migrate_offers_to_listings] failed:', error);
  process.exitCode = 1;
});