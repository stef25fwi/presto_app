"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const operating_mode_guard_1 = require("./operating_mode_guard");
(0, node_test_1.default)("refuse toute configuration absente ou bêta", () => {
    strict_1.default.equal((0, operating_mode_guard_1.isCommercialBillingEnabled)(undefined), false);
    strict_1.default.equal((0, operating_mode_guard_1.isCommercialBillingEnabled)({}), false);
    strict_1.default.equal((0, operating_mode_guard_1.isCommercialBillingEnabled)({
        operatingMode: "free_beta",
        subscriptionSectionEnabled: true,
        stripeEnabled: true,
        freeAccessMode: false,
    }), false);
});
(0, node_test_1.default)("exige les quatre indicateurs commerciaux cohérents", () => {
    const valid = {
        operatingMode: "commercial",
        subscriptionSectionEnabled: true,
        stripeEnabled: true,
        freeAccessMode: false,
    };
    strict_1.default.equal((0, operating_mode_guard_1.isCommercialBillingEnabled)(valid), true);
    strict_1.default.equal((0, operating_mode_guard_1.isCommercialBillingEnabled)({ ...valid, stripeEnabled: false }), false);
    strict_1.default.equal((0, operating_mode_guard_1.isCommercialBillingEnabled)({ ...valid, freeAccessMode: true }), false);
    strict_1.default.equal((0, operating_mode_guard_1.isCommercialBillingEnabled)({ ...valid, subscriptionSectionEnabled: false }), false);
});
(0, node_test_1.default)("refuse une acceptation bêta après passage commercial", () => {
    const legal = {
        operatingMode: "commercial",
        legalVersion: "commercial-v1",
        cguVersion: "cgu-commercial-v1",
        privacyVersion: "privacy-commercial-v1",
    };
    const user = {
        legalAcceptance: {
            operatingMode: "free_beta",
            legalVersion: "beta-free-v1",
            cguVersion: "cgu-beta-free-v1",
            privacyVersion: "privacy-beta-free-v1",
        },
    };
    strict_1.default.equal((0, operating_mode_guard_1.hasCurrentCommercialLegalAcceptance)(user, legal), false);
});
(0, node_test_1.default)("autorise uniquement les versions commerciales exactes", () => {
    const legal = {
        operatingMode: "commercial",
        legalVersion: "commercial-v1",
        cguVersion: "cgu-commercial-v1",
        privacyVersion: "privacy-commercial-v1",
    };
    const acceptance = {
        operatingMode: "commercial",
        legalVersion: "commercial-v1",
        cguVersion: "cgu-commercial-v1",
        privacyVersion: "privacy-commercial-v1",
    };
    strict_1.default.equal((0, operating_mode_guard_1.hasCurrentCommercialLegalAcceptance)({ legalAcceptance: acceptance }, legal), true);
    strict_1.default.equal((0, operating_mode_guard_1.hasCurrentCommercialLegalAcceptance)({
        legalAcceptance: {
            ...acceptance,
            cguVersion: "cgu-commercial-v0",
        },
    }, legal), false);
});
//# sourceMappingURL=operating_mode_guard.test.js.map