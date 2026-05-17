import assert from "node:assert/strict";
import test from "node:test";

import { countRecentPublishedListingRecords } from "./scheduled";

test("countRecentPublishedListingRecords counts published canonical listings within the window", () => {
  assert.equal(
    countRecentPublishedListingRecords([
      { status: "published", publishedAt: 1_760_000_000_000 },
      { status: "active", createdAt: 1_760_000_100_000 },
      { status: "draft", publishedAt: 1_760_000_200_000 },
    ], 1_759_999_999_999),
    2,
  );
});

test("countRecentPublishedListingRecords ignores records older than the cutoff", () => {
  assert.equal(
    countRecentPublishedListingRecords([
      { status: "published", publishedAt: 1_759_000_000_000 },
      { status: "active", createdAt: 1_758_000_000_000 },
    ], 1_760_000_000_000),
    0,
  );
});

test("countRecentPublishedListingRecords ignores non published statuses", () => {
  assert.equal(
    countRecentPublishedListingRecords([
      { status: "pending", publishedAt: 1_760_000_000_000 },
      { status: "draft", createdAt: 1_760_000_100_000 },
      { isActive: true, createdAt: 1_760_000_200_000 },
    ], 1_759_999_999_999),
    0,
  );
});