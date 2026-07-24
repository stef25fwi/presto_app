"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeCorrelationId = normalizeCorrelationId;
exports.resolveCorrelationId = resolveCorrelationId;
exports.buildOperationLogContext = buildOperationLogContext;
const node_crypto_1 = require("node:crypto");
const CORRELATION_ID_PATTERN = /^[A-Za-z0-9._:-]{8,80}$/;
function normalizeCorrelationId(value) {
    const normalized = String(value ?? "").trim();
    if (!CORRELATION_ID_PATTERN.test(normalized))
        return null;
    return normalized;
}
function resolveCorrelationId(value) {
    return normalizeCorrelationId(value) ?? (0, node_crypto_1.randomUUID)();
}
function buildOperationLogContext({ correlationId, operation, actorId, }) {
    const normalizedOperation = String(operation).trim();
    if (!normalizedOperation) {
        throw new Error("operation is required");
    }
    const context = {
        correlationId: resolveCorrelationId(correlationId),
        operation: normalizedOperation,
    };
    const normalizedActorId = String(actorId ?? "").trim();
    if (normalizedActorId)
        context.actorId = normalizedActorId;
    return context;
}
//# sourceMappingURL=correlation.js.map