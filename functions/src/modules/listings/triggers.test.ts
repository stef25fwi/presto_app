import assert from "node:assert/strict";
import test from "node:test";

import { COLLECTIONS, LEGACY_COLLECTIONS } from "../../shared/constants";
import {
  buildListingRouteUrl,
  getSubCategory,
  shouldNotifyUserForFavoriteListing,
} from "./triggers";

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

test("getSubCategory reads canonical subCategory field", () => {
  assert.equal(getSubCategory({ subCategory: "Peinture mur" }), "Peinture mur");
});

test("getSubCategory falls back to legacy subcategory field", () => {
  assert.equal(getSubCategory({ subcategory: "Montage meuble" }), "Montage meuble");
});

test("favorite alert notifies category-only user", () => {
  const shouldNotify = shouldNotifyUserForFavoriteListing({
    userData: {
      selectedFavoriteCategories: ["Bricolage / Travaux"],
      selectedFavoriteSubcategories: [],
    },
    listingCategory: "Bricolage / Travaux",
    listingSubCategory: "Montage meuble",
  });

  assert.equal(shouldNotify, true);
});

test("favorite alert filters by selected subcategory when configured", () => {
  const shouldNotify = shouldNotifyUserForFavoriteListing({
    userData: {
      selectedFavoriteCategories: ["Bricolage / Travaux"],
      selectedFavoriteSubcategories: [
        "Bricolage / Travaux — Montage meuble",
      ],
    },
    listingCategory: "Bricolage / Travaux",
    listingSubCategory: "Peinture",
  });

  assert.equal(shouldNotify, false);
});

test("favorite alert accepts matching selected subcategory", () => {
  const shouldNotify = shouldNotifyUserForFavoriteListing({
    userData: {
      selectedFavoriteCategories: ["Bricolage / Travaux"],
      selectedFavoriteSubcategories: [
        "Bricolage / Travaux — Montage meuble",
      ],
    },
    listingCategory: "Bricolage / Travaux",
    listingSubCategory: "Montage meuble",
  });

  assert.equal(shouldNotify, true);
});