import assert from "node:assert/strict";
import test from "node:test";

import {
  buildRetentionPlan,
  DATA_RETENTION_POLICIES,
  isExpiredForRetention,
  resolveRetentionRuntimeConfig,
  retentionCutoff,
} from "./data_retention_policy";

test("la purge reste désactivée et en simulation par défaut", () => {
  assert.deepEqual(resolveRetentionRuntimeConfig({}), {
    purgeEnabled: false,
    dryRun: true,
    batchSize: 200,
  });
});

test("une activation explicite conserve le dry-run sans opt-out explicite", () => {
  assert.deepEqual(
    resolveRetentionRuntimeConfig({ RETENTION_PURGE_ENABLED: "true" }),
    {
      purgeEnabled: true,
      dryRun: true,
      batchSize: 200,
    },
  );
});

test("la purge destructive exige deux options explicites", () => {
  assert.deepEqual(
    resolveRetentionRuntimeConfig({
      RETENTION_PURGE_ENABLED: "true",
      RETENTION_PURGE_DRY_RUN: "false",
      RETENTION_PURGE_BATCH_SIZE: "999",
    }),
    {
      purgeEnabled: true,
      dryRun: false,
      batchSize: 400,
    },
  );
});

test("borne la taille de lot et ignore les valeurs non entières", () => {
  assert.equal(
    resolveRetentionRuntimeConfig({ RETENTION_PURGE_BATCH_SIZE: "0" }).batchSize,
    1,
  );
  assert.equal(
    resolveRetentionRuntimeConfig({ RETENTION_PURGE_BATCH_SIZE: "abc" }).batchSize,
    200,
  );
});

test("calcule les dates de coupure de manière déterministe", () => {
  const now = new Date("2026-07-11T12:00:00.000Z");
  assert.equal(
    retentionCutoff(now, 90).toISOString(),
    "2026-04-12T12:00:00.000Z",
  );

  const plan = buildRetentionPlan(now);
  assert.equal(plan.length, DATA_RETENTION_POLICIES.length);
  const firstPolicy = plan[0];
  assert.ok(firstPolicy);
  assert.equal(firstPolicy.collection, "app_monitoring_events");
  assert.equal(firstPolicy.cutoffIso, "2026-04-12T12:00:00.000Z");
});

test("détecte uniquement les dates valides strictement antérieures au cutoff", () => {
  const cutoff = new Date("2026-04-12T12:00:00.000Z");
  assert.equal(
    isExpiredForRetention({ value: "2026-04-12T11:59:59.999Z", cutoff }),
    true,
  );
  assert.equal(
    isExpiredForRetention({ value: "2026-04-12T12:00:00.000Z", cutoff }),
    false,
  );
  assert.equal(isExpiredForRetention({ value: "invalid", cutoff }), false);
  assert.equal(isExpiredForRetention({ value: null, cutoff }), false);
});

test("refuse une date ou une durée de rétention invalide", () => {
  assert.throws(() => buildRetentionPlan(new Date("invalid")), TypeError);
  assert.throws(() => retentionCutoff(new Date(), 0), RangeError);
  assert.throws(() => retentionCutoff(new Date(), 1.5), RangeError);
});
