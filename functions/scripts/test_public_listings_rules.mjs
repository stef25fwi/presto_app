#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
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
  where,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');

async function seedDocs(testEnv) {
  const context = testEnv.unauthenticatedContext();
  await testEnv.withSecurityRulesDisabled(async (adminContext) => {
    const db = adminContext.firestore();
    await Promise.all([
      setDoc(doc(db, 'listings', 'listing_public'), {
        status: 'active',
        visibility: 'public',
        categoryId: 'bricolage-travaux',
        cityId: '97139_les-abymes',
        cityCategoryKey: '97139_les-abymes_bricolage-travaux',
        title: 'Annonce publique',
        createdAt: new Date('2026-04-20T10:00:00Z'),
      }),
      setDoc(doc(db, 'listings', 'listing_private'), {
        status: 'pending',
        visibility: 'private',
        categoryId: 'bricolage-travaux',
        cityId: '97139_les-abymes',
        title: 'Annonce privee',
        createdAt: new Date('2026-04-20T09:00:00Z'),
      }),
      setDoc(doc(db, 'offers', 'offer_public'), {
        status: 'active',
        title: 'Offre legacy publique',
        createdAt: new Date('2026-04-19T10:00:00Z'),
      }),
      setDoc(doc(db, 'offers', 'offer_private'), {
        status: 'pending',
        title: 'Offre legacy privee',
        createdAt: new Date('2026-04-19T09:00:00Z'),
      }),
    ]);
    await assertSucceeds(getDoc(doc(context.firestore(), 'listings', 'listing_public')));
  });
}

async function main() {
  const rules = await fs.readFile(path.join(repoRoot, 'firestore.rules'), 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-presto-public-listings',
    firestore: { rules },
  });

  try {
    await seedDocs(testEnv);

    const anonDb = testEnv.unauthenticatedContext().firestore();

    await assertSucceeds(getDoc(doc(anonDb, 'listings', 'listing_public')));
    await assertFails(getDoc(doc(anonDb, 'listings', 'listing_private')));
    await assertSucceeds(
      getDocs(
        query(
          collection(anonDb, 'listings'),
          where('status', '==', 'active'),
          where('visibility', '==', 'public'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(anonDb, 'listings'),
          where('status', '==', 'active'),
          where('visibility', '==', 'public'),
          where('cityCategoryKey', '==', '97139_les-abymes_bricolage-travaux'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collection(anonDb, 'listings'),
          where('categoryId', '==', 'bricolage-travaux'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(anonDb, 'offers'),
          where('status', '==', 'active'),
        ),
      ),
    );
    await assertFails(getDoc(doc(anonDb, 'offers', 'offer_private')));

    console.log('public listings rules integration: OK');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});