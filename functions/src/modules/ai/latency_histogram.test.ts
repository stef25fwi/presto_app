import assert from "node:assert/strict";
import test from "node:test";

import {
  emptyLatencyBuckets,
  latencyBucketField,
  latencyPercentiles,
  mergeLatencyBuckets,
  percentileFromLatencyBuckets,
} from "./latency_histogram";

test("latencyBucketField assigns deterministic inclusive buckets", () => {
  assert.equal(latencyBucketField(0), "latencyLe100");
  assert.equal(latencyBucketField(100), "latencyLe100");
  assert.equal(latencyBucketField(101), "latencyLe250");
  assert.equal(latencyBucketField(90_000), "latencyLe90000");
  assert.equal(latencyBucketField(90_001), "latencyGt90000");
});

test("latencyPercentiles aggregates real histogram counts", () => {
  const rows = [
    { latencyLe100: 5, latencyLe500: 3 },
    { latencyLe1000: 1, latencyGt90000: 1 },
  ];
  assert.deepEqual(mergeLatencyBuckets(rows), {
    ...emptyLatencyBuckets(),
    latencyLe100: 5,
    latencyLe500: 3,
    latencyLe1000: 1,
    latencyGt90000: 1,
  });
  assert.deepEqual(latencyPercentiles(rows), {
    p50: 100,
    p90: 1000,
    p95: 90001,
    p99: 90001,
  });
});

test("empty histograms return null percentiles", () => {
  assert.equal(percentileFromLatencyBuckets(emptyLatencyBuckets(), 0.95), null);
});
