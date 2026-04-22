// Audit détaillé : vérifier si des champs tombent sous isOfferArchivedLike
const admin = require('../functions/node_modules/firebase-admin');
const PROJECT_ID = 'presto-app-74abe';
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
    serviceAccountId: `${PROJECT_ID}@appspot.gserviceaccount.com`,
  });
}
const db = admin.firestore();

(async () => {
  const snap = await db
    .collection('listings')
    .where('status', '==', 'active')
    .where('visibility', '==', 'public')
    .orderBy('createdAt', 'desc')
    .limit(10)
    .get();
  console.log(`docs returned by query: ${snap.size}`);
  snap.forEach((doc) => {
    const d = doc.data();
    const flags = {
      id: doc.id,
      status: d.status,
      visibility: d.visibility,
      archivedAt: d.archivedAt || null,
      deletedAt: d.deletedAt || null,
      jobDoneOverlayVisible: d.jobDoneOverlayVisible ?? null,
      removeFromBrowseAt: d.removeFromBrowseAt || null,
      pendingScreenRemovalUntil: d.pendingScreenRemovalUntil || null,
      jobDoneOverlayVisibleUntil: d.jobDoneOverlayVisibleUntil || null,
      isPublished: d.isPublished ?? null,
      isActive: d.isActive ?? null,
      keys: Object.keys(d).sort().join(','),
    };
    console.log(JSON.stringify(flags));
  });
})();
