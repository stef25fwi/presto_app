"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const idempotency_1 = require("./idempotency");
(0, node_test_1.default)("normalizeClientRequestId removes unsafe characters and limits length", () => {
    const normalized = (0, idempotency_1.normalizeClientRequestId)(`  request / utilisateur ? ${"x".repeat(220)}  `);
    strict_1.default.match(normalized, /^[a-zA-Z0-9_.:-]+$/);
    strict_1.default.ok(normalized.length <= 180);
});
(0, node_test_1.default)("deriveClientRequestId is stable for identical inputs", () => {
    const first = (0, idempotency_1.deriveClientRequestId)(["texte", "Baie-Mahault", "Jardinage"]);
    const second = (0, idempotency_1.deriveClientRequestId)(["texte", "Baie-Mahault", "Jardinage"]);
    const different = (0, idempotency_1.deriveClientRequestId)(["texte", "Les Abymes", "Jardinage"]);
    strict_1.default.equal(first, second);
    strict_1.default.notEqual(first, different);
    strict_1.default.equal(first.length, 40);
});
(0, node_test_1.default)("idempotency document id separates users and operations", () => {
    const base = (0, idempotency_1.buildIdempotencyDocumentId)("user-a", "draft", "request-1");
    const otherUser = (0, idempotency_1.buildIdempotencyDocumentId)("user-b", "draft", "request-1");
    const otherOperation = (0, idempotency_1.buildIdempotencyDocumentId)("user-a", "vision", "request-1");
    strict_1.default.notEqual(base, otherUser);
    strict_1.default.notEqual(base, otherOperation);
    strict_1.default.equal(base.length, 64);
});
//# sourceMappingURL=idempotency.test.js.map