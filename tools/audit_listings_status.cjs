#!/usr/bin/env node
const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({ projectId: 'presto-app-74abe' });
const db = admin.firestore();

async function main() {
  const snap = await db.collection('listings').limit(100).get();
  console.log(`Total listings trouvées: ${snap.size}`);
  const byStatus = {};
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const s = d.status || '(none)';
    byStatus[s] = (byStatus[s] || 0) + 1;
    const photos = d.photoUrls || d.photos || d.mediaUrls || d.imageUrls || [];
    const thumbs = d.thumbnailUrls || d.thumbnails || [];
    const media = d.media || [];
    console.log(JSON.stringify({
      id: doc.id,
      title: (d.title || '').substring(0, 40),
      status: s,
      moderationStatus: d.moderationStatus || '(none)',
      mediaProcessingStatus: d.mediaProcessingStatus || '(none)',
      visibility: d.visibility || '(none)',
      photoCount: Array.isArray(photos) ? photos.length : 0,
      thumbCount: Array.isArray(thumbs) ? thumbs.length : 0,
      mediaCount: Array.isArray(media) ? media.length : 0,
      thumbnailUrl: d.thumbnailUrl || '(none)',
      mediaFirst: media[0] ? JSON.stringify(media[0]).substring(0, 100) : '(none)',
      hasPhotoUrls: !!d.photoUrls,
      hasPhotos: !!d.photos,
      hasMediaUrls: !!d.mediaUrls,
      hasImageUrls: !!d.imageUrls,
      hasThumbnailUrls: !!d.thumbnailUrls,
      hasThumbnails: !!d.thumbnails,
      hasMedia: !!d.media,
      createdAt: d.createdAt ? d.createdAt.toDate?.().toISOString?.() || String(d.createdAt) : '(none)',
    }));
  }
  console.log('\nRépartition par status:', JSON.stringify(byStatus, null, 2));

  // Also check drafts
  const draftSnap = await db.collection('listingDrafts').limit(50).get();
  console.log(`\nTotal drafts: ${draftSnap.size}`);
  for (const doc of draftSnap.docs) {
    const d = doc.data() || {};
    console.log(JSON.stringify({
      id: doc.id,
      title: (d.title || '').substring(0, 40),
      status: d.status || '(none)',
      ownerId: (d.ownerId || '').substring(0, 20),
    }));
  }
}

main().catch(e => { console.error(e); process.exitCode = 1; });
