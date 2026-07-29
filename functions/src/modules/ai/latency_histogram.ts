export const LATENCY_BUCKETS_MS = [
  100,
  250,
  500,
  1_000,
  2_000,
  5_000,
  10_000,
  20_000,
  45_000,
  90_000,
] as const;

export type LatencyBucketField =
  | "latencyLe100"
  | "latencyLe250"
  | "latencyLe500"
  | "latencyLe1000"
  | "latencyLe2000"
  | "latencyLe5000"
  | "latencyLe10000"
  | "latencyLe20000"
  | "latencyLe45000"
  | "latencyLe90000"
  | "latencyGt90000";

const BUCKET_FIELDS: readonly LatencyBucketField[] = [
  "latencyLe100",
  "latencyLe250",
  "latencyLe500",
  "latencyLe1000",
  "latencyLe2000",
  "latencyLe5000",
  "latencyLe10000",
  "latencyLe20000",
  "latencyLe45000",
  "latencyLe90000",
  "latencyGt90000",
];

export function latencyBucketField(durationMs: number): LatencyBucketField {
  const duration = Math.max(0, Number.isFinite(durationMs) ? durationMs : 0);
  const index = LATENCY_BUCKETS_MS.findIndex((bound) => duration <= bound);
  return index >= 0 ? BUCKET_FIELDS[index]! : "latencyGt90000";
}

export function emptyLatencyBuckets(): Record<LatencyBucketField, number> {
  return Object.fromEntries(BUCKET_FIELDS.map((field) => [field, 0])) as Record<
    LatencyBucketField,
    number
  >;
}

export function mergeLatencyBuckets(
  rows: readonly Record<string, unknown>[],
): Record<LatencyBucketField, number> {
  const merged = emptyLatencyBuckets();
  for (const row of rows) {
    for (const field of BUCKET_FIELDS) {
      const value = Number(row[field] || 0);
      if (Number.isFinite(value) && value > 0) merged[field] += value;
    }
  }
  return merged;
}

export function percentileFromLatencyBuckets(
  buckets: Readonly<Record<LatencyBucketField, number>>,
  percentile: number,
): number | null {
  const total = BUCKET_FIELDS.reduce(
    (sum, field) => sum + Math.max(0, Number(buckets[field] || 0)),
    0,
  );
  if (total <= 0) return null;
  const target = Math.max(1, Math.ceil(total * Math.max(0, Math.min(1, percentile))));
  let cumulative = 0;
  for (let index = 0; index < BUCKET_FIELDS.length; index += 1) {
    cumulative += Math.max(0, Number(buckets[BUCKET_FIELDS[index]!] || 0));
    if (cumulative >= target) {
      return index < LATENCY_BUCKETS_MS.length
        ? LATENCY_BUCKETS_MS[index]!
        : 90_001;
    }
  }
  return 90_001;
}

export function latencyPercentiles(
  rows: readonly Record<string, unknown>[],
): { p50: number | null; p90: number | null; p95: number | null; p99: number | null } {
  const buckets = mergeLatencyBuckets(rows);
  return {
    p50: percentileFromLatencyBuckets(buckets, 0.5),
    p90: percentileFromLatencyBuckets(buckets, 0.9),
    p95: percentileFromLatencyBuckets(buckets, 0.95),
    p99: percentileFromLatencyBuckets(buckets, 0.99),
  };
}
