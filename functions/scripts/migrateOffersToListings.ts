import admin from "firebase-admin";

import { initAdmin, isActiveLegacyOffer, normalizeString, parseCommonArgs, pickOwnerId, pickTimestamp } from "./_shared";

function buildListingDoc(id: string, data: Record<string, unknown>) {
  const ownerId = pickOwnerId(data);
  const title = normalizeString(data.title);
  const description = normalizeString(data.description);
  const price = Number(data.price || 0) || 0;
  const media = Array.isArray(data.media) ? data.media : [];
  const imageUrls = Array.isArray(data.imageUrls)
    ? data.imageUrls.map((entry) => normalizeString(entry)).filter(Boolean)
    : media
        .map((entry) => normalizeString((entry as Record<string, unknown>)?.downloadUrl))
        .filter(Boolean);

  return {
    id,
    ownerId,
    title,
    description,
    price,
    categoryId: normalizeString(data.categoryId),
    cityId: normalizeString(data.cityId),
    media,
    imageUrls,
    status: "active",
    visibility: "public",
    migratedFrom: `offers/${id}`,
    createdAt: pickTimestamp(data.createdAt) || admin.firestore.Timestamp.now(),
    updatedAt: pickTimestamp(data.updatedAt) || admin.firestore.Timestamp.now(),
    publishedAt: pickTimestamp(data.publishedAt) || pickTimestamp(data.createdAt) || admin.firestore.Timestamp.now(),
  };
}

async function main() {
  const options = parseCommonArgs(process.argv);
  const db = initAdmin(options.projectId);
  const offers = await db.collection("offers").get();

  let scanned = 0;
  let migrated = 0;
  let skippedExisting = 0;
  let skippedInactive = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const offerDoc of offers.docs) {
    scanned += 1;
    const data = offerDoc.data() as Record<string, unknown>;
    if (!isActiveLegacyOffer(data)) {
      skippedInactive += 1;
      continue;
    }

    const listingRef = db.collection("listings").doc(offerDoc.id);
    const listingSnap = await listingRef.get();
    if (listingSnap.exists) {
      skippedExisting += 1;
      continue;
    }

    const listingDoc = buildListingDoc(offerDoc.id, data);
    if (options.dryRun) {
      console.log(`[dry-run] offers/${offerDoc.id} -> listings/${offerDoc.id}`);
      migrated += 1;
      continue;
    }

    batch.set(listingRef, listingDoc, { merge: false });
    batchCount += 1;
    migrated += 1;
    if (batchCount >= 400) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (!options.dryRun && batchCount > 0) {
    await batch.commit();
  }

  console.log(JSON.stringify({ scanned, migrated, skippedExisting, skippedInactive, dryRun: options.dryRun }, null, 2));
}

void main().catch((error) => {
  console.error("[migrateOffersToListings] failed", error);
  process.exitCode = 1;
});