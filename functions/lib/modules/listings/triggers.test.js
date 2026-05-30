"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const constants_1 = require("../../shared/constants");
const triggers_1 = require("./triggers");
(0, node_test_1.default)("buildListingRouteUrl uses canonical listings route", () => {
    strict_1.default.equal((0, triggers_1.buildListingRouteUrl)(constants_1.COLLECTIONS.listings, "listing_123"), "https://presto.app/listings/listing_123");
});
(0, node_test_1.default)("buildListingRouteUrl keeps legacy offers route", () => {
    strict_1.default.equal((0, triggers_1.buildListingRouteUrl)(constants_1.LEGACY_COLLECTIONS.offers, "offer_123"), "https://presto.app/offers/offer_123");
});
(0, node_test_1.default)("getSubCategory reads canonical subCategory field", () => {
    strict_1.default.equal((0, triggers_1.getSubCategory)({ subCategory: "Peinture mur" }), "Peinture mur");
});
(0, node_test_1.default)("getSubCategory falls back to legacy subcategory field", () => {
    strict_1.default.equal((0, triggers_1.getSubCategory)({ subcategory: "Montage meuble" }), "Montage meuble");
});
(0, node_test_1.default)("favorite alert notifies category-only user", () => {
    const shouldNotify = (0, triggers_1.shouldNotifyUserForFavoriteListing)({
        userData: {
            selectedFavoriteCategories: ["Bricolage / Travaux"],
            selectedFavoriteSubcategories: [],
        },
        listingCategory: "Bricolage / Travaux",
        listingSubCategory: "Montage meuble",
    });
    strict_1.default.equal(shouldNotify, true);
});
(0, node_test_1.default)("favorite alert filters by selected subcategory when configured", () => {
    const shouldNotify = (0, triggers_1.shouldNotifyUserForFavoriteListing)({
        userData: {
            selectedFavoriteCategories: ["Bricolage / Travaux"],
            selectedFavoriteSubcategories: [
                "Bricolage / Travaux — Montage meuble",
            ],
        },
        listingCategory: "Bricolage / Travaux",
        listingSubCategory: "Peinture",
    });
    strict_1.default.equal(shouldNotify, false);
});
(0, node_test_1.default)("favorite alert accepts matching selected subcategory", () => {
    const shouldNotify = (0, triggers_1.shouldNotifyUserForFavoriteListing)({
        userData: {
            selectedFavoriteCategories: ["Bricolage / Travaux"],
            selectedFavoriteSubcategories: [
                "Bricolage / Travaux — Montage meuble",
            ],
        },
        listingCategory: "Bricolage / Travaux",
        listingSubCategory: "Montage meuble",
    });
    strict_1.default.equal(shouldNotify, true);
});
//# sourceMappingURL=triggers.test.js.map