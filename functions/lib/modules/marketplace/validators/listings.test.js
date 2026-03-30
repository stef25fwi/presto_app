"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const errors_1 = require("../services/errors");
const listings_1 = require("./listings");
(0, node_test_1.default)("validateListingDraftPayload normalizes a valid listing draft", () => {
    const payload = (0, listings_1.validateListingDraftPayload)({
        title: "Montage meuble cuisine complet",
        description: "Montage d'un meuble de cuisine avec fixation murale et finitions propres.",
        price: "95",
        categoryId: "bricolage-travaux",
        cityId: "97139_les-abymes",
        media: [
            {
                storagePath: "listings/u1/photo.webp",
                downloadUrl: "https://cdn.example/photo.webp",
                mimeType: "image/webp",
            },
        ],
    }, 10);
    strict_1.default.equal(payload.price, 95);
    strict_1.default.equal(payload.thumbnailUrl, "https://cdn.example/photo.webp");
    strict_1.default.equal(payload.media.length, 1);
    strict_1.default.ok(payload.searchKeywords.includes("montage"));
    strict_1.default.ok(payload.searchKeywords.includes("bricolage"));
    strict_1.default.ok(payload.searchKeywords.includes("97139"));
});
(0, node_test_1.default)("validateListingDraftPayload reports aggregated issues", () => {
    strict_1.default.throws(() => (0, listings_1.validateListingDraftPayload)({
        title: "Court",
        description: "Trop court",
        price: -1,
        categoryId: "",
        cityId: "",
        media: [],
    }, 4), (error) => {
        strict_1.default.ok(error instanceof errors_1.ValidationError);
        strict_1.default.ok(error.issues.includes("Title must contain at least 10 characters"));
        strict_1.default.ok(error.issues.includes("Description must contain at least 30 characters"));
        strict_1.default.ok(error.issues.includes("Price must be a positive number"));
        strict_1.default.ok(error.issues.includes("At least one photo is required"));
        return true;
    });
});
(0, node_test_1.default)("validateListingDraftPayload rejects non-webp media", () => {
    strict_1.default.throws(() => (0, listings_1.validateListingDraftPayload)({
        title: "Montage meuble cuisine complet",
        description: "Montage d'un meuble de cuisine avec fixation murale et finitions propres.",
        price: "95",
        categoryId: "bricolage-travaux",
        cityId: "97139_les-abymes",
        media: [
            {
                storagePath: "listings/u1/photo.jpg",
                downloadUrl: "https://cdn.example/photo.jpg",
                mimeType: "image/jpeg",
            },
        ],
    }, 10), (error) => {
        strict_1.default.ok(error instanceof errors_1.ValidationError);
        strict_1.default.ok(error.issues.includes("Photo #1 must be processed as WebP before submission"));
        return true;
    });
});
(0, node_test_1.default)("validateListingReportPayload rejects unsupported reason codes", () => {
    strict_1.default.throws(() => (0, listings_1.validateListingReportPayload)({
        listingId: "listing_123",
        reasonCode: "unknown_reason",
    }), (error) => {
        strict_1.default.ok(error instanceof errors_1.ValidationError);
        strict_1.default.deepEqual(error.issues, ["reasonCode is invalid"]);
        return true;
    });
});
//# sourceMappingURL=listings.test.js.map