#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { initializeApp as initializeAdminApp } from 'firebase-admin/app';
import {
  FieldValue,
  Timestamp,
  getFirestore as getAdminFirestore,
} from 'firebase-admin/firestore';
import { initializeApp as initializeClientApp, deleteApp } from 'firebase/app';
import {
  collection,
  connectFirestoreEmulator,
  getDocs,
  getFirestore as getClientFirestore,
  limit,
  orderBy,
  query,
  startAfter,
  where,
} from 'firebase/firestore';

const projectId = process.env.GCLOUD_PROJECT || 'demo-presto-load-1000';
const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const virtualUsers = Number(process.env.LOAD_VIRTUAL_USERS || 1000);
const concurrency = Number(process.env.LOAD_CONCURRENCY || 100);
const pageSize = Number(process.env.LOAD_PAGE_SIZE || 20);
const maxErrorRate = Number(process.env.LOAD_MAX_ERROR_RATE || 0.01);
const maxP95Ms = Number(process.env.LOAD_MAX_P95_MS || 2500);
const seedCount = Math.max(240, pageSize * 10);

if (!emulatorHost) {
  throw new Error('FIRESTORE_EMULATOR_HOST is required. Never run this script against production.');
}
if (!Number.isInteger(virtualUsers) || virtualUsers < 1 || virtualUsers > 5000) {
  throw new Error(`Invalid LOAD_VIRTUAL_USERS: ${virtualUsers}`);
}
if (!Number.isInteger(concurrency) || concurrency < 1 || concurrency > 500) {
  throw new Error(`Invalid LOAD_CONCURRENCY: ${concurrency}`);
}

function percentile(values, ratio) {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.ceil(sorted.length * ratio) - 1);
  return sorted[index];
}

async function seedListings(adminDb) {
  let batch = adminDb.batch();
  let batchSize = 0;

  for (let index = 0; index < seedCount; index += 1) {
    const categoryId = `cat_${index % 5}`;
    const cityId = `971_${index % 8}`;
    const ref = adminDb.collection('listings').doc(`load_listing_${index}`);
    batch.set(ref, {
      ownerId: `seed_owner_${index % 20}`,
      title: `Annonce de charge ${index}`,
      status: 'active',
      visibility: 'public',
      categoryId,
      cityId,
      cityCategoryKey: `${cityId}_${categoryId}`,
      createdAt: Timestamp.fromMillis(Date.now() - index * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batchSize += 1;

    if (batchSize >= 400) {
      await batch.commit();
      batch = adminDb.batch();
      batchSize = 0;
    }
  }

  if (batchSize > 0) await batch.commit();
}

function buildBrowseQuery(db, scenario) {
  const filters = [
    where('status', '==', 'active'),
    where('visibility', '==', 'public'),
  ];

  if (scenario === 1) filters.push(where('categoryId', '==', 'cat_1'));
  if (scenario === 2) filters.push(where('cityId', '==', '971_2'));
  if (scenario === 3) {
    filters.push(where('cityCategoryKey', '==', '971_3_cat_3'));
  }

  return query(
    collection(db, 'listings'),
    ...filters,
    orderBy('createdAt', 'desc'),
    limit(pageSize),
  );
}

async function runVirtualSession(db, virtualUserIndex) {
  const startedAt = performance.now();
  const scenario = virtualUserIndex % 4;
  const firstPage = await getDocs(buildBrowseQuery(db, scenario));
  if (firstPage.empty) {
    throw new Error(`Scenario ${scenario} returned no listing`);
  }
  if (firstPage.size > pageSize) {
    throw new Error(`Scenario ${scenario} exceeded page size`);
  }

  const lastDocument = firstPage.docs.at(-1);
  if (lastDocument && firstPage.size === pageSize) {
    const secondPage = await getDocs(
      query(buildBrowseQuery(db, scenario), startAfter(lastDocument)),
    );
    if (secondPage.size > pageSize) {
      throw new Error(`Scenario ${scenario} second page exceeded page size`);
    }
    const firstIds = new Set(firstPage.docs.map((document) => document.id));
    if (secondPage.docs.some((document) => firstIds.has(document.id))) {
      throw new Error(`Scenario ${scenario} cursor returned duplicate listings`);
    }
  }

  return performance.now() - startedAt;
}

async function runPool(taskCount, poolSize, task) {
  const durations = [];
  const errors = [];
  let nextIndex = 0;

  async function worker() {
    while (true) {
      const currentIndex = nextIndex;
      nextIndex += 1;
      if (currentIndex >= taskCount) return;

      try {
        durations.push(await task(currentIndex));
      } catch (error) {
        errors.push({
          virtualUser: currentIndex,
          message: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(poolSize, taskCount) }, () => worker()),
  );
  return { durations, errors };
}

async function main() {
  const [host, portText] = emulatorHost.split(':');
  const port = Number(portText || 8080);

  const adminApp = initializeAdminApp({ projectId });
  const adminDb = getAdminFirestore(adminApp);
  await seedListings(adminDb);

  const clientApp = initializeClientApp(
    {
      apiKey: 'emulator-only-key',
      appId: '1:123:web:emulator',
      projectId,
    },
    `load-test-${Date.now()}`,
  );
  const clientDb = getClientFirestore(clientApp);
  connectFirestoreEmulator(clientDb, host, port);

  const suiteStartedAt = performance.now();
  const { durations, errors } = await runPool(
    virtualUsers,
    concurrency,
    (index) => runVirtualSession(clientDb, index),
  );
  const totalDurationMs = performance.now() - suiteStartedAt;
  const errorRate = errors.length / virtualUsers;
  const p50Ms = percentile(durations, 0.5);
  const p95Ms = percentile(durations, 0.95);
  const p99Ms = percentile(durations, 0.99);

  const result = {
    environment: 'firestore-emulator',
    projectId,
    virtualUsers,
    concurrency,
    pageSize,
    queriesPerSuccessfulSession: 2,
    successfulSessions: durations.length,
    failedSessions: errors.length,
    errorRate,
    totalDurationMs,
    sessionsPerSecond: virtualUsers / (totalDurationMs / 1000),
    latencyMs: { p50: p50Ms, p95: p95Ms, p99: p99Ms },
    thresholds: { maxErrorRate, maxP95Ms },
    firstErrors: errors.slice(0, 20),
  };

  const outputDirectory = path.resolve('..', 'load-tests', 'results');
  await fs.mkdir(outputDirectory, { recursive: true });
  await fs.writeFile(
    path.join(outputDirectory, 'firestore-emulator-1000-users.json'),
    `${JSON.stringify(result, null, 2)}\n`,
    'utf8',
  );

  console.log(JSON.stringify(result, null, 2));
  await deleteApp(clientApp);

  if (errorRate > maxErrorRate) {
    throw new Error(`Load-test error rate ${errorRate} exceeds ${maxErrorRate}`);
  }
  if (p95Ms > maxP95Ms) {
    throw new Error(`Load-test p95 ${p95Ms.toFixed(1)}ms exceeds ${maxP95Ms}ms`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
