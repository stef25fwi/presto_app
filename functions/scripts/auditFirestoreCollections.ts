import { parseCommonArgs, initAdmin, isActiveLegacyOffer, normalizeString, writeJsonReport } from "./_shared";

async function countCollection(db: FirebaseFirestore.Firestore, collectionName: string): Promise<number> {
  const snapshot = await db.collection(collectionName).count().get();
  return snapshot.data().count;
}

async function sampleLegacyDocs(db: FirebaseFirestore.Firestore, collectionName: string) {
  const snapshot = await db.collection(collectionName).limit(25).get();
  return snapshot.docs.map((doc) => {
    const data = doc.data() as Record<string, unknown>;
    return {
      id: doc.id,
      ownerId: normalizeString(data.ownerId || data.userId || data.uid),
      status: normalizeString(data.status),
      title: normalizeString(data.title || data.displayName || data.name),
      active: isActiveLegacyOffer(data),
    };
  });
}

async function main() {
  const options = parseCommonArgs(process.argv);
  const db = initAdmin(options.projectId);
  const collections = ["offers", "listings", "profiles", "user_profiles", "listing_drafts", "listingDrafts"];

  const counts = Object.fromEntries(
    await Promise.all(collections.map(async (name) => [name, await countCollection(db, name)])),
  );

  const [offersSample, listingDraftsSample, profilesSample, userProfilesSample] = await Promise.all([
    sampleLegacyDocs(db, "offers"),
    sampleLegacyDocs(db, "listing_drafts"),
    sampleLegacyDocs(db, "profiles"),
    sampleLegacyDocs(db, "user_profiles"),
  ]);

  const report = {
    generatedAt: new Date().toISOString(),
    projectId: options.projectId,
    counts,
    legacyActive: {
      offers: offersSample.filter((entry) => entry.active),
      listing_drafts: listingDraftsSample.filter((entry) => entry.active),
      profiles: profilesSample,
      user_profiles: userProfilesSample,
    },
  };

  await writeJsonReport(report, options.outPath || "functions/reports/firestore-collections-audit.json");
}

void main().catch((error) => {
  console.error("[auditFirestoreCollections] failed", error);
  process.exitCode = 1;
});