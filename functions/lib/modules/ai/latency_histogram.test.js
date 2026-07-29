"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const latency_histogram_1 = require("./latency_histogram");
(0, node_test_1.default)("latencyBucketField assigns deterministic inclusive buckets", () => {
    strict_1.default.equal((0, latency_histogram_1.latencyBucketField)(0), "latencyLe100");
    strict_1.default.equal((0, latency_histogram_1.latencyBucketField)(100), "latencyLe100");
    strict_1.default.equal((0, latency_histogram_1.latencyBucketField)(101), "latencyLe250");
    strict_1.default.equal((0, latency_histogram_1.latencyBucketField)(90_000), "latencyLe90000");
    strict_1.default.equal((0, latency_histogram_1.latencyBucketField)(90_001), "latencyGt90000");
});
(0, node_test_1.default)("latencyPercentiles aggregates real histogram counts", () => {
    const rows = [
        { latencyLe100: 5, latencyLe500: 3 },
        { latencyLe1000: 1, latencyGt90000: 1 },
    ];
    strict_1.default.deepEqual((0, latency_histogram_1.mergeLatencyBuckets)(rows), {
        ...(0, latency_histogram_1.emptyLatencyBuckets)(),
        latencyLe100: 5,
        latencyLe500: 3,
        latencyLe1000: 1,
        latencyGt90000: 1,
    });
    strict_1.default.deepEqual((0, latency_histogram_1.latencyPercentiles)(rows), {
        p50: 100,
        p90: 1000,
        p95: 90001,
        p99: 90001,
    });
});
(0, node_test_1.default)("empty histograms return null percentiles", () => {
    strict_1.default.equal((0, latency_histogram_1.percentileFromLatencyBuckets)((0, latency_histogram_1.emptyLatencyBuckets)(), 0.95), null);
});
//# sourceMappingURL=latency_histogram.test.js.map