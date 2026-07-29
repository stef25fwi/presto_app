#!/usr/bin/env node

import process from "node:process";
import admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

const requestedDays = Number(process.argv[2] || 14);
const days = Math.min(90, Math.max(1, Math.round(requestedDays)));
const start = new Date(Date.now() - (days - 1) * 24 * 60 * 60 * 1000)
  .toISOString()
  .slice(0, 10);

const snapshot = await admin
  .firestore()
  .collection("_ai_metrics_daily")
  .where("day", ">=", start)
  .orderBy("day", "desc")
  .limit(1000)
  .get();

const rows = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
const totals = rows.reduce(
  (acc, row) => {
    acc.count += Number(row.count || 0);
    acc.successCount += Number(row.successCount || 0);
    acc.failureCount += Number(row.failureCount || 0);
    acc.fallbackCount += Number(row.fallbackCount || 0);
    acc.cacheHitCount += Number(row.cacheHitCount || 0);
    acc.totalDurationMs += Number(row.totalDurationMs || 0);
    acc.estimatedCostMicrosEur += Number(row.estimatedCostMicrosEur || 0);
    return acc;
  },
  {
    count: 0,
    successCount: 0,
    failureCount: 0,
    fallbackCount: 0,
    cacheHitCount: 0,
    totalDurationMs: 0,
    estimatedCostMicrosEur: 0,
  },
);

const report = {
  days,
  start,
  totals: {
    ...totals,
    successRate: totals.count ? totals.successCount / totals.count : null,
    averageDurationMs: totals.count
      ? Math.round(totals.totalDurationMs / totals.count)
      : null,
    fallbackRate: totals.count ? totals.fallbackCount / totals.count : null,
    cacheHitRate: totals.count ? totals.cacheHitCount / totals.count : null,
    estimatedCostEur: totals.estimatedCostMicrosEur / 1_000_000,
  },
  rows,
};

console.log(JSON.stringify(report, null, 2));
process.exit(0);
