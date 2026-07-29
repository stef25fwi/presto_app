"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LATENCY_BUCKETS_MS = void 0;
exports.latencyBucketField = latencyBucketField;
exports.emptyLatencyBuckets = emptyLatencyBuckets;
exports.mergeLatencyBuckets = mergeLatencyBuckets;
exports.percentileFromLatencyBuckets = percentileFromLatencyBuckets;
exports.latencyPercentiles = latencyPercentiles;
exports.LATENCY_BUCKETS_MS = [
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
];
const BUCKET_FIELDS = [
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
function latencyBucketField(durationMs) {
    const duration = Math.max(0, Number.isFinite(durationMs) ? durationMs : 0);
    const index = exports.LATENCY_BUCKETS_MS.findIndex((bound) => duration <= bound);
    return index >= 0 ? BUCKET_FIELDS[index] : "latencyGt90000";
}
function emptyLatencyBuckets() {
    return Object.fromEntries(BUCKET_FIELDS.map((field) => [field, 0]));
}
function mergeLatencyBuckets(rows) {
    const merged = emptyLatencyBuckets();
    for (const row of rows) {
        for (const field of BUCKET_FIELDS) {
            const value = Number(row[field] || 0);
            if (Number.isFinite(value) && value > 0)
                merged[field] += value;
        }
    }
    return merged;
}
function percentileFromLatencyBuckets(buckets, percentile) {
    const total = BUCKET_FIELDS.reduce((sum, field) => sum + Math.max(0, Number(buckets[field] || 0)), 0);
    if (total <= 0)
        return null;
    const target = Math.max(1, Math.ceil(total * Math.max(0, Math.min(1, percentile))));
    let cumulative = 0;
    for (let index = 0; index < BUCKET_FIELDS.length; index += 1) {
        cumulative += Math.max(0, Number(buckets[BUCKET_FIELDS[index]] || 0));
        if (cumulative >= target) {
            return index < exports.LATENCY_BUCKETS_MS.length
                ? exports.LATENCY_BUCKETS_MS[index]
                : 90_001;
        }
    }
    return 90_001;
}
function latencyPercentiles(rows) {
    const buckets = mergeLatencyBuckets(rows);
    return {
        p50: percentileFromLatencyBuckets(buckets, 0.5),
        p90: percentileFromLatencyBuckets(buckets, 0.9),
        p95: percentileFromLatencyBuckets(buckets, 0.95),
        p99: percentileFromLatencyBuckets(buckets, 0.99),
    };
}
//# sourceMappingURL=latency_histogram.js.map