"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const enrich_1 = require("./enrich");
const constants_1 = require("../../../shared/constants");
(0, node_test_1.default)("billing invoice enrichment adds currency, method and retry info", () => {
    const source = {
        amount_due: 39.99,
        currency: "EUR",
        payment_method_label: "Carte Visa **** 4242",
        next_retry_at: 1760000000000,
    };
    const payload = {};
    const extra = (0, enrich_1.buildBillingInvoiceEnrichment)(source, payload);
    strict_1.default.equal(extra.amount, 39.99);
    strict_1.default.equal(extra.currency, "EUR");
    strict_1.default.equal(extra.paymentMethod, "Carte Visa **** 4242");
    strict_1.default.equal(extra.nextRetryAt, 1760000000000);
    strict_1.default.equal(extra.retryUrl, "https://presto.app/facturation");
});
(0, node_test_1.default)("billing invoice enrichment respects existing payload values", () => {
    const source = {
        amount_due: 39.99,
        currency: "USD",
        payment_method_label: "Card",
        next_retry_at: 1760000000000,
    };
    const payload = {
        amount: 10,
        currency: "EUR",
        paymentMethod: "SEPA",
        nextRetryAt: 1,
        retryUrl: "https://x",
    };
    const extra = (0, enrich_1.buildBillingInvoiceEnrichment)(source, payload);
    strict_1.default.equal(extra.amount, undefined);
    strict_1.default.equal(extra.currency, undefined);
    strict_1.default.equal(extra.paymentMethod, undefined);
    strict_1.default.equal(extra.nextRetryAt, undefined);
    strict_1.default.equal(extra.retryUrl, undefined);
});
(0, node_test_1.default)("subscription enrichment defaults plan and manageUrl", () => {
    const source = {
        current_period_end: 1760000000000,
        payment_method: "SEPA",
    };
    const payload = {};
    const extra = (0, enrich_1.buildSubscriptionEnrichment)(source, payload);
    strict_1.default.equal(extra.planName, "PRESTO Premium");
    strict_1.default.equal(extra.currency, "EUR");
    strict_1.default.equal(extra.paymentMethod, "SEPA");
    strict_1.default.equal(extra.manageUrl, "https://presto.app/abonnement");
    strict_1.default.equal(typeof extra.renewalDate, "string");
});
(0, node_test_1.default)("listing enrichment uses canonical listing URL for listings", () => {
    const extra = (0, enrich_1.buildListingLikeEnrichment)({
        sourceCollection: constants_1.COLLECTIONS.listings,
        sourceId: "listing_123",
        source: { title: "Listing marketplace", city: "Paris" },
        payload: {},
    });
    strict_1.default.equal(extra.listingTitle, "Listing marketplace");
    strict_1.default.equal(extra.listingUrl, "https://presto.app/listings/listing_123");
    strict_1.default.equal(extra.city, "Paris");
});
(0, node_test_1.default)("listing enrichment keeps legacy offer URL for historical offers events", () => {
    const extra = (0, enrich_1.buildListingLikeEnrichment)({
        sourceCollection: constants_1.LEGACY_COLLECTIONS.offers,
        sourceId: "offer_123",
        source: { title: "Offre legacy" },
        payload: {},
        fallbackCity: "Lyon",
    });
    strict_1.default.equal(extra.listingTitle, "Offre legacy");
    strict_1.default.equal(extra.listingUrl, "https://presto.app/offers/offer_123");
    strict_1.default.equal(extra.city, "Lyon");
});
//# sourceMappingURL=enrich.test.js.map