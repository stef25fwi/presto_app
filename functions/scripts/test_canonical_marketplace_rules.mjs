#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');

async function seedDocs(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (adminContext) => {
    const db = adminContext.firestore();
    await Promise.all([
      setDoc(doc(db, 'users', 'user_1'), {
        displayName: 'User One',
        email: 'user1@example.com',
      }),
      setDoc(doc(db, 'profiles', 'user_1'), {
        userId: 'user_1',
        displayName: 'Legacy User One',
      }),
      setDoc(doc(db, 'listings', 'listing_public'), {
        ownerId: 'user_1',
        status: 'active',
        visibility: 'public',
        updatedAt: new Date('2026-05-01T10:00:00Z'),
      }),
      setDoc(doc(db, 'offers', 'offer_legacy_public'), {
        ownerId: 'user_1',
        status: 'active',
        title: 'Legacy public offer',
      }),
      setDoc(doc(db, 'notifications', 'notif_1'), {
        userId: 'user_1',
        read: false,
      }),
      setDoc(doc(db, 'conversations', 'conv_seed'), {
        participantIds: ['user_1', 'user_2'],
        updatedAt: new Date('2026-05-01T11:00:00Z'),
      }),
      setDoc(doc(db, 'conversations', 'conv_seed', 'messages', 'msg_1'), {
        senderId: 'user_1',
        text: 'Bonjour',
      }),
    ]);
  });
}

async function main() {
  const rules = await fs.readFile(path.join(repoRoot, 'firestore.rules'), 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-presto-canonical-rules',
    firestore: { rules },
  });

  try {
    await seedDocs(testEnv);

    const anonDb = testEnv.unauthenticatedContext().firestore();
    const userDb = testEnv.authenticatedContext('user_1').firestore();

    // Limitation du SDK de test: request.app/App Check n'est pas simulable ici.
    // On couvre donc les refus sans App Check, qui sont le fail-closed critique.
    await assertFails(setDoc(doc(anonDb, 'users', 'anon_user'), { displayName: 'Anon' }));
    await assertFails(setDoc(doc(userDb, 'users', 'user_1'), { displayName: 'X' }));
    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { displayName: 'Y' }));
    await assertFails(setDoc(doc(userDb, 'users', 'user_1', 'favoriteOffers', 'listing_public'), {
      listingId: 'listing_public',
    }));
    await assertFails(updateDoc(doc(userDb, 'users', 'user_1', 'favoriteOffers', 'listing_public'), {
      listingId: 'listing_public',
    }));

    await assertFails(setDoc(doc(userDb, 'profiles', 'user_1'), {
      userId: 'user_1',
      displayName: 'Legacy write',
    }));
    await assertFails(updateDoc(doc(userDb, 'profiles', 'user_1'), {
      displayName: 'Legacy update',
    }));

    await assertSucceeds(getDoc(doc(anonDb, 'listings', 'listing_public')));
    await assertFails(setDoc(doc(userDb, 'listings', 'listing_new'), { ownerId: 'user_1' }));
    await assertFails(updateDoc(doc(userDb, 'listings', 'listing_public'), { title: 'Mutated' }));

    await assertSucceeds(getDoc(doc(anonDb, 'offers', 'offer_legacy_public')));
    await assertFails(setDoc(doc(userDb, 'offers', 'offer_new'), { ownerId: 'user_1' }));
    await assertFails(updateDoc(doc(userDb, 'offers', 'offer_legacy_public'), { title: 'Mutated' }));

    await assertFails(getDoc(doc(userDb, 'notifications', 'notif_1')));
    await assertFails(setDoc(doc(userDb, 'listingReports', 'report_1'), { reporterId: 'user_1' }));
    await assertFails(setDoc(doc(userDb, 'conversations', 'conv_new'), {
      participantIds: ['user_1', 'user_2'],
      updatedAt: new Date('2026-05-01T12:00:00Z'),
    }));
    await assertFails(updateDoc(doc(userDb, 'conversations', 'conv_seed'), {
      updatedAt: new Date('2026-05-01T12:00:00Z'),
    }));
    await assertFails(setDoc(doc(userDb, 'conversations', 'conv_seed', 'messages', 'msg_2'), {
      senderId: 'user_1',
      text: 'Bonjour encore',
    }));

    await assertSucceeds(
      getDocs(
        query(
          collection(anonDb, 'listings'),
          where('status', '==', 'active'),
          where('visibility', '==', 'public'),
          orderBy('updatedAt', 'desc'),
        ),
      ),
    );

    console.log('canonical marketplace rules integration: OK');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});