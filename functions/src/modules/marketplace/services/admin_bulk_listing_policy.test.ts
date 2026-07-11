import assert from "node:assert/strict";
import test from "node:test";
import {
  AdminBulkListingInputError,
  executeAdminBulkListingDeletion,
  normalizeAdminBulkListingIds,
} from "./admin_bulk_listing_policy";

test("normalizeAdminBulkListingIds trims and deduplicates identifiers", () => {
  assert.deepEqual(
    normalizeAdminBulkListingIds([" a ", "", "b", "a", null, " c "]),
    ["a", "b", "c"],
  );
});

test("normalizeAdminBulkListingIds rejects invalid or oversized payloads", () => {
  assert.throws(
    () => normalizeAdminBulkListingIds("a"),
    AdminBulkListingInputError,
  );
  assert.throws(
    () => normalizeAdminBulkListingIds([]),
    AdminBulkListingInputError,
  );
  assert.throws(
    () => normalizeAdminBulkListingIds(["a", "b", "c"], 2),
    AdminBulkListingInputError,
  );
});

test("executeAdminBulkListingDeletion preserves order and partial failures", async () => {
  const calls: string[] = [];
  const summary = await executeAdminBulkListingDeletion({
    listingIds: ["a", "b", "c"],
    concurrency: 2,
    deleteOne: async (listingId) => {
      calls.push(listingId);
      if (listingId === "b") {
        const error = new Error("Listing not found") as Error & { code?: string };
        error.code = "not-found";
        throw error;
      }
    },
  });

  assert.deepEqual(calls.sort(), ["a", "b", "c"]);
  assert.equal(summary.requestedCount, 3);
  assert.equal(summary.succeededCount, 2);
  assert.equal(summary.failedCount, 1);
  assert.deepEqual(summary.results, [
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

test("executeAdminBulkListingDeletion rejects invalid concurrency", async () => {
  await assert.rejects(
    executeAdminBulkListingDeletion({
      listingIds: ["a"],
      concurrency: 0,
      deleteOne: async () => undefined,
    }),
    AdminBulkListingInputError,
  );
});
