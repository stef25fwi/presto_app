import assert from "node:assert/strict";
import test from "node:test";

import { COLLECTIONS, LEGACY_COLLECTIONS } from "../../shared/constants";
import { buildListingRouteUrl } from "./triggers";

test("buildListingRouteUrl uses canonical listings route", () => {
  assert.equal(
    buildListingRouteUrl(COLLECTIONS.listings, "listing_123"),
    "https://presto.app/listings/listing_123",
  );
});

test("buildListingRouteUrl keeps legacy offers route", () => {
  assert.equal(
    buildListingRouteUrl(LEGACY_COLLECTIONS.offers, "offer_123"),
    "https://presto.app/offers/offer_123",
  );
});