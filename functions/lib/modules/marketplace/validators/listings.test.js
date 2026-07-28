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
        category: "Bricolage / Travaux",
        city: "Les Abymes",
        location: "Les Abymes",
        postalCode: "97139",
        cp: "97139",
        dept: "971",
        region: "01",
        cityCategoryKey: "97139_les-abymes_bricolage-travaux",
        budgetValue: 95,
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
    strict_1.default.equal("width" in payload.media[0], false);
    strict_1.default.equal("height" in payload.media[0], false);
    strict_1.default.equal("sizeBytes" in payload.media[0], false);
    strict_1.default.equal(payload.city, "Les Abymes");
    strict_1.default.equal(payload.postalCode, "97139");
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
        return true;
    });
});
(0, node_test_1.default)("validateListingDraftPayload allows publishing without photos", () => {
    const payload = (0, listings_1.validateListingDraftPayload)({
        title: "Montage meuble cuisine complet",
        description: "Montage d'un meuble de cuisine avec fixation murale et finitions propres.",
        price: "95",
        categoryId: "bricolage-travaux",
        cityId: "97139_les-abymes",
        media: [],
    }, 10);
    strict_1.default.equal(payload.media.length, 0);
    strict_1.default.equal(payload.thumbnailUrl, "");
});
(0, node_test_1.default)("validateListingDraftPayload accepts raw image formats for backend conversion", () => {
    const payload = (0, listings_1.validateListingDraftPayload)({
        title: "Montage meuble cuisine complet",
        description: "Montage d'un meuble de cuisine avec fixation murale et finitions propres.",
        price: "95",
        categoryId: "bricolage-travaux",
        cityId: "97139_les-abymes",
        media: [
            {
                storagePath: "listingDrafts/u1/draft_1/photo.jpg",
                downloadUrl: "https://cdn.example/photo.jpg",
                mimeType: "image/jpeg",
            },
        ],
    }, 10);
    strict_1.default.equal(payload.media.length, 1);
    strict_1.default.equal(payload.media[0]?.mimeType, "image/jpeg");
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
(0, node_test_1.default)("validateConversationReportPayload normalizes a valid report", () => {
    const payload = (0, listings_1.validateConversationReportPayload)({
        conversationId: "offer_listing_123__uidA__uidB",
        messageId: " msg_1 ",
        reasonCode: "harassment",
        reasonText: "  Propos déplacés répétés  ",
    });
    strict_1.default.equal(payload.conversationId, "offer_listing_123__uidA__uidB");
    strict_1.default.equal(payload.messageId, "msg_1");
    strict_1.default.equal(payload.reasonCode, "harassment");
    strict_1.default.equal(payload.reasonText, "Propos déplacés répétés");
});
(0, node_test_1.default)("validateConversationReportPayload allows an omitted messageId", () => {
    const payload = (0, listings_1.validateConversationReportPayload)({
        conversationId: "offer_listing_123__uidA__uidB",
        reasonCode: "spam",
    });
    strict_1.default.equal(payload.messageId, undefined);
    strict_1.default.equal(payload.reasonText, undefined);
});
(0, node_test_1.default)("validateConversationReportPayload rejects a missing conversationId", () => {
    strict_1.default.throws(() => (0, listings_1.validateConversationReportPayload)({
        reasonCode: "spam",
    }), (error) => {
        strict_1.default.ok(error instanceof errors_1.ValidationError);
        strict_1.default.deepEqual(error.issues, ["conversationId is required"]);
        return true;
    });
});
(0, node_test_1.default)("validateConversationReportPayload rejects unsupported reason codes", () => {
    strict_1.default.throws(() => (0, listings_1.validateConversationReportPayload)({
        conversationId: "offer_listing_123__uidA__uidB",
        reasonCode: "wrong_category",
    }), (error) => {
        strict_1.default.ok(error instanceof errors_1.ValidationError);
        strict_1.default.deepEqual(error.issues, ["reasonCode is invalid"]);
        return true;
    });
});
(0, node_test_1.default)("validateConversationReportPayload rejects an over-long reasonText", () => {
    strict_1.default.throws(() => (0, listings_1.validateConversationReportPayload)({
        conversationId: "offer_listing_123__uidA__uidB",
        reasonCode: "other",
        reasonText: "x".repeat(801),
    }), (error) => {
        strict_1.default.ok(error instanceof errors_1.ValidationError);
        strict_1.default.deepEqual(error.issues, ["reasonText is too long"]);
        return true;
    });
});
//# sourceMappingURL=listings.test.js.map