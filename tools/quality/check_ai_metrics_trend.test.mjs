#!/usr/bin/env node
import assert from 'node:assert/strict';

import {
  defaultThresholds,
  evaluateTrendGates,
  expectedDays,
  summarizeTrend,
} from '../../functions/scripts/ai_metrics_trend.mjs';

const now = new Date('2026-08-04T09:00:00.000Z');

function dayKey(offset) {
  return new Date(now.getTime() - offset * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function row(offset, overrides = {}) {
  return {
    day: dayKey(offset),
    operation: 'micro_ia_listing',
    count: 10,
    successCount: 10,
    failureCount: 0,
    fallbackCount: 0,
    cacheHitCount: 2,
    totalDurationMs: 20_000,
    totalAudioSeconds: 60,
    estimatedCostMicrosEur: 120_000,
    latencyLe2000: 8,
    latencyLe5000: 2,
    ...overrides,
  };
}

const thresholds = defaultThresholds({});

assert.equal(expectedDays(3, now).length, 3);
assert.equal(expectedDays(3, now).at(-1), dayKey(0));

// Trente jours pleins : accumulation atteinte et aucun manquement.
const healthyRows = Array.from({ length: 30 }, (_, index) => row(index));
const healthy = summarizeTrend(healthyRows, { days: 30, now, thresholds });
assert.equal(healthy.observedDays, 30);
assert.equal(healthy.accumulationComplete, true);
assert.deepEqual(healthy.missingDays, []);
assert.equal(healthy.windows.d14.days, 14);
assert.equal(healthy.windows.d14.count, 140);
assert.equal(healthy.windows.d30.successRate, 1);
assert.deepEqual(evaluateTrendGates(healthy), []);

// Cinq jours de mesures ne prouvent rien sur la durée.
const sparse = summarizeTrend(
  Array.from({ length: 5 }, (_, index) => row(index)),
  { days: 30, now, thresholds },
);
assert.equal(sparse.observedDays, 5);
assert.equal(sparse.accumulationComplete, false);
assert.equal(sparse.missingDays.length, 25);
const sparseFailures = evaluateTrendGates(sparse);
assert.match(sparseFailures.join(' | '), /accumulation insuffisante/);

// Un volume trop faible interdit de conclure sur les seuils de qualité.
const lowVolume = summarizeTrend(
  Array.from({ length: 30 }, (_, index) => row(index, { count: 1, successCount: 1, latencyLe2000: 1, latencyLe5000: 0 })),
  { days: 30, now, thresholds },
);
assert.match(evaluateTrendGates(lowVolume).join(' | '), /volume insuffisant/);

// Des échecs répétés doivent sortir la fenêtre de référence des seuils.
const degraded = summarizeTrend(
  Array.from({ length: 30 }, (_, index) =>
    row(index, { successCount: 8, failureCount: 2, fallbackCount: 3 }),
  ),
  { days: 30, now, thresholds },
);
const degradedFailures = evaluateTrendGates(degraded);
assert.match(degradedFailures.join(' | '), /taux de succès 0\.8 < 0\.98/);
assert.match(degradedFailures.join(' | '), /taux de fallback 0\.3 > 0\.1/);

// Les latences sont lues sur les histogrammes de production, pas sur la moyenne.
const slow = summarizeTrend(
  Array.from({ length: 30 }, (_, index) =>
    row(index, { latencyLe2000: 0, latencyLe5000: 0, latencyLe45000: 10 }),
  ),
  { days: 30, now, thresholds },
);
assert.match(evaluateTrendGates(slow).join(' | '), /P95 45000 ms > 20000 ms/);

// Le plafond de coût journalier est optionnel et ne s'applique que s'il est défini.
const costly = summarizeTrend(
  Array.from({ length: 30 }, (_, index) =>
    row(index, { estimatedCostMicrosEur: index === 0 ? 9_000_000 : 120_000 }),
  ),
  { days: 30, now, thresholds: { ...thresholds, maxDailyCostEur: 5 } },
);
assert.match(evaluateTrendGates(costly).join(' | '), /coût 9 € le/);

// Les documents antérieurs à la fenêtre demandée sont ignorés.
const outOfRange = summarizeTrend([row(45)], { days: 30, now, thresholds });
assert.equal(outOfRange.observedDays, 0);
assert.equal(outOfRange.windows.d30.count, 0);

// La ventilation par opération sert au diagnostic sans exposer de contenu.
const mixed = summarizeTrend(
  [row(0), row(1, { operation: 'micro_ia_transcription' })],
  { days: 7, now, thresholds },
);
assert.deepEqual(Object.keys(mixed.byOperation).sort(), [
  'micro_ia_listing',
  'micro_ia_transcription',
]);

console.log('AI metrics trend tests passed.');
