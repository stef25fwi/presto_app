"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const correlation_1 = require("./correlation");
(0, node_test_1.default)("accepte uniquement les identifiants de corrélation sûrs", () => {
    strict_1.default.equal((0, correlation_1.normalizeCorrelationId)(" request-1234 "), "request-1234");
    strict_1.default.equal((0, correlation_1.normalizeCorrelationId)("short"), null);
    strict_1.default.equal((0, correlation_1.normalizeCorrelationId)("invalid id with spaces"), null);
    strict_1.default.equal((0, correlation_1.normalizeCorrelationId)("<script>alert(1)</script>"), null);
});
(0, node_test_1.default)("génère un UUID lorsque la valeur cliente est invalide", () => {
    const generated = (0, correlation_1.resolveCorrelationId)("");
    strict_1.default.match(generated, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
});
(0, node_test_1.default)("construit un contexte de log normalisé", () => {
    strict_1.default.deepEqual((0, correlation_1.buildOperationLogContext)({
        correlationId: "request-1234",
        operation: " admin_bulk_delete_listings ",
        actorId: " admin-1 ",
    }), {
        correlationId: "request-1234",
        operation: "admin_bulk_delete_listings",
        actorId: "admin-1",
    });
});
(0, node_test_1.default)("refuse un contexte sans nom d opération", () => {
    strict_1.default.throws(() => (0, correlation_1.buildOperationLogContext)({
        correlationId: "request-1234",
        operation: "   ",
    }), /operation is required/);
});
//# sourceMappingURL=correlation.test.js.map