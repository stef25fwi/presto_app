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
  deleteDoc,
  doc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');

async function main() {
  const rules = await fs.readFile(path.join(repoRoot, 'firestore.rules'), 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-presto-user-authority-rules',
    firestore: { rules },
  });

  try {
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await setDoc(doc(adminContext.firestore(), 'users', 'user_1'), {
        uid: 'user_1',
        displayName: 'Utilisateur',
        role: 'user',
        accountStatus: 'active',
        subscriptionPlan: 'free',
        subscriptionStatus: 'inactive',
        phoneVerified: false,
        proVerified: false,
      });
    });

    const userDb = testEnv.authenticatedContext('user_1').firestore();
    const userRef = doc(userDb, 'users', 'user_1');

    await assertSucceeds(updateDoc(userRef, { displayName: 'Nouveau pseudo' }));

    const forbiddenUpdates = [
      { uid: 'another_user' },
      { email: 'attacker@example.com' },
      { subscriptionPlan: 'ilipro' },
      { subscriptionStatus: 'active' },
      { subscriptionExpiresAt: new Date('2099-01-01T00:00:00Z') },
      { stripeCustomerId: 'cus_fake' },
      { stripeSubscriptionId: 'sub_fake' },
      { stripePriceId: 'price_fake' },
      { phoneVerified: true },
      { proVerified: true },
      { siretVerified: true },
      { emailVerified: true },
      { accountStatus: 'active' },
      { role: 'admin' },
    ];

    for (const update of forbiddenUpdates) {
      await assertFails(updateDoc(userRef, update));
    }

    await assertFails(deleteDoc(userRef));

    console.log('user authority rules integration: OK');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
