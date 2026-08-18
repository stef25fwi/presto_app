#!/usr/bin/env node
'use strict';

/**
 * E2E suppression de compte iliprestō.
 *
 * Ce test est volontairement limité aux émulateurs Firebase et à un projet
 * `demo-*` afin qu'il soit impossible de supprimer des données réelles par
 * erreur.
 *
 * Usage depuis le dossier functions/ :
 *   npm run build
 *   npx --yes firebase-tools@15 emulators:exec \
 *     --project demo-ilipresto-account-deletion \
 *     --config ../firebase.json \
 *     --only auth,firestore,storage \
 *     "node scripts/account_deletion_e2e.cjs"
 */

const assert = require('node:assert/strict');

function requireEmulator(name) {
  const value = String(process.env[name] || '').trim();
  if (!value) {
    throw new Error(`${name} absent : ce test doit tourner uniquement dans les émulateurs Firebase.`);
  }
  return value;
}

async function assertDocumentMissing(ref, label) {
  const snapshot = await ref.get();
  assert.equal(snapshot.exists, false, `${label} doit être supprimé`);
}

async function assertFileMissing(bucket, path, label) {
  const [exists] = await bucket.file(path).exists();
  assert.equal(exists, false, `${label} doit être supprimé du Storage`);
}

async function main() {
  requireEmulator('FIREBASE_AUTH_EMULATOR_HOST');
  requireEmulator('FIRESTORE_EMULATOR_HOST');
  requireEmulator('FIREBASE_STORAGE_EMULATOR_HOST');

  const projectId = String(
    process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || '',
  ).trim();
  if (!projectId.startsWith('demo-')) {
    throw new Error(
      `Projet refusé (${projectId || 'non défini'}) : utilisez obligatoirement un projet demo-*.`
    );
  }

  const admin = require('../lib/core/firebase_admin_compat.js');
  if (admin.apps.length === 0) {
    admin.initializeApp({
      projectId,
      storageBucket: `${projectId}.appspot.com`,
    });
  }

  const { db } = require('../lib/core/firestore.js');
  const { executeAccountDeletion } = require('../lib/modules/auth/account_deletion.js');

  const auth = admin.auth();
  const bucket = admin.storage().bucket();
  const suffix = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const uid = `account_delete_e2e_${suffix}`;
  const otherUid = `account_delete_peer_${suffix}`;
  const listingId = `listing_${suffix}`;
  const conversationId = `conversation_${suffix}`;
  const reviewId = `review_${suffix}`;
  const receivedReviewId = `received_review_${suffix}`;
  const reportId = `report_${suffix}`;
  const replyId = `reply_${suffix}`;

  const userRef = db.collection('users').doc(uid);
  const phoneRateLimitRef = userRef.collection('rateLimits').doc('phoneVerification');
  const listingRef = db.collection('listings').doc(listingId);
  const conversationRef = db.collection('conversations').doc(conversationId);
  const messageRef = conversationRef.collection('messages').doc(`message_${suffix}`);
  const reviewRef = db.collection('reviews').doc(reviewId);
  const receivedReviewRef = db.collection('reviews').doc(receivedReviewId);
  const reportRef = db.collection('review_reports').doc(reportId);
  const replyRef = db.collection('review_replies').doc(replyId);
  const proProfileRef = db.collection('pro_profiles').doc(uid);
  const proRateLimitRef = db.collection('pro_verification_rate_limits').doc(uid);
  const proLogRef = db.collection('pro_verification_logs').doc(`log_${suffix}`);
  const notificationRef = db.collection('notifications').doc(`notification_${suffix}`);
  const listingPrivateContactRef = db.collection('listingPrivateContacts').doc(listingId);

  const storagePaths = [
    `profilePhotos/${uid}/avatar.jpg`,
    `listingDrafts/${uid}/draft_${suffix}/draft.jpg`,
    `listings/${uid}/${listingId}/photo.jpg`,
    `messageAttachments/${uid}/${conversationId}/attachment.txt`,
    `offers_raw/${uid}/legacy.jpg`,
    `offers/${uid}/legacy.jpg`,
    `stt_streaming/${uid}/1_chunk.webm`,
    `stt/${uid}_${suffix}.webm`,
    `moderation_review/${listingId}/moderation.jpg`,
    `rejected_ad_images/${listingId}/rejected.jpg`,
  ];

  console.log(`E2E suppression : création du compte ${uid}`);
  await auth.createUser({
    uid,
    email: `${uid}@example.test`,
    password: 'Test-Account-Deletion-42!',
    displayName: 'Compte E2E suppression',
    phoneNumber: '+33600000001',
  });

  await userRef.set({
    email: `${uid}@example.test`,
    displayName: 'Compte E2E suppression',
    firstName: 'Compte',
    lastName: 'E2E',
    phone: '+33600000001',
    phoneVerified: true,
    siret: '13002526500013',
    siretVerified: true,
    accountStatus: 'active',
    subscriptionPlan: 'free',
  });
  await phoneRateLimitRef.set({
    reservationState: 'sent',
    phoneSuffix: '0001',
  });

  await proProfileRef.set({
    uid,
    siret: '13002526500013',
    companyName: 'Entreprise E2E',
    verified: true,
  });
  await proRateLimitRef.set({ uid, count: 1 });
  await proLogRef.set({
    uid,
    siret: '13002526500013',
    success: true,
  });

  await listingRef.set({
    ownerId: uid,
    ownerDisplayName: 'Compte E2E suppression',
    status: 'active',
    visibility: 'public',
    title: 'Annonce E2E suppression',
    media: [
      {
        storagePath: storagePaths[2],
        downloadUrl: 'https://example.invalid/e2e.jpg',
      },
    ],
  });
  await listingPrivateContactRef.set({
    ownerId: uid,
    phone: '+33600000001',
  });

  await conversationRef.set({
    participantIds: [uid, otherUid],
    participants: [uid, otherUid],
    participantNames: {
      [uid]: 'Compte E2E suppression',
      [otherUid]: 'Correspondant E2E',
    },
    lastSenderId: uid,
    lastSenderName: 'Compte E2E suppression',
    lastMessage: 'Message personnel E2E',
  });
  await messageRef.set({
    senderId: uid,
    sender_id: uid,
    senderName: 'Compte E2E suppression',
    sender_name: 'Compte E2E suppression',
    text: 'Message personnel E2E',
    body: 'Message personnel E2E',
  });

  await reviewRef.set({
    reviewerId: uid,
    reviewedUserId: otherUid,
    comment: 'Avis E2E donné par le compte supprimé',
  });
  await receivedReviewRef.set({
    reviewerId: otherUid,
    reviewedUserId: uid,
    comment: 'Avis E2E reçu par le compte supprimé',
  });
  await reportRef.set({
    reviewId: receivedReviewId,
    reportedBy: uid,
    details: 'Signalement E2E',
  });
  await replyRef.set({
    reviewId: receivedReviewId,
    reviewedUserId: uid,
    replyText: 'Réponse E2E',
  });

  await notificationRef.set({
    userId: uid,
    title: 'Notification E2E',
  });

  for (const path of storagePaths) {
    await bucket.file(path).save(Buffer.from(`probe:${path}`), {
      resumable: false,
      metadata: { contentType: 'application/octet-stream' },
    });
  }

  // Preuve du parcours demandé : compte créé + annonce publiée + données
  // personnelles associées existent avant la suppression.
  assert.equal((await auth.getUser(uid)).uid, uid);
  assert.equal((await userRef.get()).exists, true);
  assert.equal((await listingRef.get()).data()?.status, 'active');
  assert.equal((await messageRef.get()).exists, true);
  assert.equal((await reviewRef.get()).exists, true);
  for (const path of storagePaths) {
    const [exists] = await bucket.file(path).exists();
    assert.equal(exists, true, `précondition Storage absente : ${path}`);
  }

  console.log('E2E suppression : exécution du nettoyeur serveur');
  const result = await executeAccountDeletion(uid);
  assert.equal(result.ok, true);
  assert.ok(result.archivedListings >= 1, 'au moins une annonce doit être archivée');
  assert.ok(result.deletedMessages >= 1, 'au moins un message doit être supprimé');
  assert.ok(result.deletedFiles >= storagePaths.length, 'tous les fichiers de test doivent être supprimés');

  await assert.rejects(
    () => auth.getUser(uid),
    (error) => error && error.code === 'auth/user-not-found',
    'Firebase Authentication doit supprimer le compte',
  );

  await assertDocumentMissing(userRef, 'users/{uid}');
  await assertDocumentMissing(phoneRateLimitRef, 'rateLimits/phoneVerification');
  await assertDocumentMissing(proProfileRef, 'pro_profiles/{uid}');
  await assertDocumentMissing(proRateLimitRef, 'pro_verification_rate_limits/{uid}');
  await assertDocumentMissing(proLogRef, 'pro_verification_logs');
  await assertDocumentMissing(reviewRef, 'avis rédigé par le compte');
  await assertDocumentMissing(receivedReviewRef, 'avis reçu par le compte');
  await assertDocumentMissing(reportRef, 'signalement d’avis du compte');
  await assertDocumentMissing(replyRef, 'réponse à un avis du compte');
  await assertDocumentMissing(notificationRef, 'notification du compte');
  await assertDocumentMissing(messageRef, 'message envoyé par le compte');
  await assertDocumentMissing(listingPrivateContactRef, 'coordonnées privées de l’annonce');

  const retainedListing = await listingRef.get();
  assert.equal(retainedListing.exists, true, 'la métadonnée d’annonce peut être conservée pour preuve');
  assert.equal(retainedListing.data()?.status, 'deleted');
  assert.equal(retainedListing.data()?.visibility, 'private');
  assert.equal(retainedListing.data()?.ownerDisplayName, 'Utilisateur supprimé');
  assert.equal(retainedListing.data()?.ownerPhotoUrl ?? null, null);

  const retainedConversation = await conversationRef.get();
  assert.equal(retainedConversation.exists, true, 'la conversation de l’autre participant doit subsister');
  assert.equal(
    retainedConversation.data()?.participantNames?.[uid],
    'Utilisateur supprimé',
  );
  assert.equal(retainedConversation.data()?.deletedBy?.[uid], true);
  assert.equal(retainedConversation.data()?.lastMessage, 'Message supprimé');
  assert.equal(retainedConversation.data()?.lastSenderId, '');

  for (const path of storagePaths) {
    await assertFileMissing(bucket, path, path);
  }

  console.log('OK — suppression E2E certifiée sur émulateurs Auth/Firestore/Storage');
  console.log(JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error('ÉCHEC — account_deletion_e2e');
  console.error(error);
  process.exitCode = 1;
});
