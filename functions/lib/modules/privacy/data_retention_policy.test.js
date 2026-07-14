"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const data_retention_policy_1 = require("./data_retention_policy");
(0, node_test_1.default)("la purge reste désactivée et en simulation par défaut", () => {
    strict_1.default.deepEqual((0, data_retention_policy_1.resolveRetentionRuntimeConfig)({}), {
        purgeEnabled: false,
        dryRun: true,
        batchSize: 200,
    });
});
(0, node_test_1.default)("une activation explicite conserve le dry-run sans opt-out explicite", () => {
    strict_1.default.deepEqual((0, data_retention_policy_1.resolveRetentionRuntimeConfig)({ RETENTION_PURGE_ENABLED: "true" }), {
        purgeEnabled: true,
        dryRun: true,
        batchSize: 200,
    });
});
(0, node_test_1.default)("la purge destructive exige deux options explicites", () => {
    strict_1.default.deepEqual((0, data_retention_policy_1.resolveRetentionRuntimeConfig)({
        RETENTION_PURGE_ENABLED: "true",
        RETENTION_PURGE_DRY_RUN: "false",
        RETENTION_PURGE_BATCH_SIZE: "999",
    }), {
        purgeEnabled: true,
        dryRun: false,
        batchSize: 400,
    });
});
(0, node_test_1.default)("borne la taille de lot et ignore les valeurs non entières", () => {
    strict_1.default.equal((0, data_retention_policy_1.resolveRetentionRuntimeConfig)({ RETENTION_PURGE_BATCH_SIZE: "0" }).batchSize, 1);
    strict_1.default.equal((0, data_retention_policy_1.resolveRetentionRuntimeConfig)({ RETENTION_PURGE_BATCH_SIZE: "abc" }).batchSize, 200);
});
(0, node_test_1.default)("calcule les dates de coupure de manière déterministe", () => {
    const now = new Date("2026-07-11T12:00:00.000Z");
    strict_1.default.equal((0, data_retention_policy_1.retentionCutoff)(now, 90).toISOString(), "2026-04-12T12:00:00.000Z");
    const plan = (0, data_retention_policy_1.buildRetentionPlan)(now);
    strict_1.default.equal(plan.length, data_retention_policy_1.DATA_RETENTION_POLICIES.length);
    const firstPolicy = plan[0];
    strict_1.default.ok(firstPolicy);
    strict_1.default.equal(firstPolicy.collection, "app_monitoring_events");
    strict_1.default.equal(firstPolicy.cutoffIso, "2026-04-12T12:00:00.000Z");
});
(0, node_test_1.default)("détecte uniquement les dates valides strictement antérieures au cutoff", () => {
    const cutoff = new Date("2026-04-12T12:00:00.000Z");
    strict_1.default.equal((0, data_retention_policy_1.isExpiredForRetention)({ value: "2026-04-12T11:59:59.999Z", cutoff }), true);
    strict_1.default.equal((0, data_retention_policy_1.isExpiredForRetention)({ value: "2026-04-12T12:00:00.000Z", cutoff }), false);
    strict_1.default.equal((0, data_retention_policy_1.isExpiredForRetention)({ value: "invalid", cutoff }), false);
    strict_1.default.equal((0, data_retention_policy_1.isExpiredForRetention)({ value: null, cutoff }), false);
});
(0, node_test_1.default)("refuse une date ou une durée de rétention invalide", () => {
    strict_1.default.throws(() => (0, data_retention_policy_1.buildRetentionPlan)(new Date("invalid")), TypeError);
    strict_1.default.throws(() => (0, data_retention_policy_1.retentionCutoff)(new Date(), 0), RangeError);
    strict_1.default.throws(() => (0, data_retention_policy_1.retentionCutoff)(new Date(), 1.5), RangeError);
});
//# sourceMappingURL=data_retention_policy.test.js.map