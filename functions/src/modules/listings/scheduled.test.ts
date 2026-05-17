import assert from "node:assert/strict";
import test from "node:test";

import { hasPublishedListingRecords } from "./scheduled";

test("hasPublishedListingRecords accepts canonical published listings", () => {
  assert.equal(
    hasPublishedListingRecords([
      { status: "draft" },
      { status: "published" },
    ]),
    true,
  );
});

test("hasPublishedListingRecords accepts active legacy-like records", () => {
  assert.equal(
    hasPublishedListingRecords([
      { status: "inactive" },
      { isActive: true },
    ]),
    true,
  );
});

test("hasPublishedListingRecords rejects non published records", () => {
  assert.equal(
    hasPublishedListingRecords([
      { status: "draft" },
      { status: "pending" },
    ]),
    false,
  );
});