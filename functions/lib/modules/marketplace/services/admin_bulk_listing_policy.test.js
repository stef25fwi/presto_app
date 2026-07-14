"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const admin_bulk_listing_policy_1 = require("./admin_bulk_listing_policy");
(0, node_test_1.default)("normalizeAdminBulkListingIds trims and deduplicates identifiers", () => {
    strict_1.default.deepEqual((0, admin_bulk_listing_policy_1.normalizeAdminBulkListingIds)([" a ", "", "b", "a", null, " c "]), ["a", "b", "c"]);
});
(0, node_test_1.default)("normalizeAdminBulkListingIds rejects invalid or oversized payloads", () => {
    strict_1.default.throws(() => (0, admin_bulk_listing_policy_1.normalizeAdminBulkListingIds)("a"), admin_bulk_listing_policy_1.AdminBulkListingInputError);
    strict_1.default.throws(() => (0, admin_bulk_listing_policy_1.normalizeAdminBulkListingIds)([]), admin_bulk_listing_policy_1.AdminBulkListingInputError);
    strict_1.default.throws(() => (0, admin_bulk_listing_policy_1.normalizeAdminBulkListingIds)(["a", "b", "c"], 2), admin_bulk_listing_policy_1.AdminBulkListingInputError);
});
(0, node_test_1.default)("executeAdminBulkListingDeletion preserves order and partial failures", async () => {
    const calls = [];
    const summary = await (0, admin_bulk_listing_policy_1.executeAdminBulkListingDeletion)({
        listingIds: ["a", "b", "c"],
        concurrency: 2,
        deleteOne: async (listingId) => {
            calls.push(listingId);
            if (listingId === "b") {
                const error = new Error("Listing not found");
                error.code = "not-found";
                throw error;
            }
        },
    });
    strict_1.default.deepEqual(calls.sort(), ["a", "b", "c"]);
    strict_1.default.equal(summary.requestedCount, 3);
    strict_1.default.equal(summary.succeededCount, 2);
    strict_1.default.equal(summary.failedCount, 1);
    strict_1.default.deepEqual(summary.results, [
        { listingId: "a", ok: true },
        {
            listingId: "b",
            ok: false,
            errorCode: "not-found",
            errorMessage: "Listing not found",
        },
        { listingId: "c", ok: true },
    ]);
});
(0, node_test_1.default)("executeAdminBulkListingDeletion rejects invalid concurrency", async () => {
    await strict_1.default.rejects((0, admin_bulk_listing_policy_1.executeAdminBulkListingDeletion)({
        listingIds: ["a"],
        concurrency: 0,
        deleteOne: async () => undefined,
    }), admin_bulk_listing_policy_1.AdminBulkListingInputError);
});
//# sourceMappingURL=admin_bulk_listing_policy.test.js.map