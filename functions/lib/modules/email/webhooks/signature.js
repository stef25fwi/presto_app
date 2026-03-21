"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeHeaders = normalizeHeaders;
function normalizeHeaders(input) {
    if (!input || typeof input !== "object")
        return {};
    const headers = input;
    return Object.fromEntries(Object.entries(headers)
        .filter(([, value]) => typeof value === "string")
        .map(([key, value]) => [key, String(value)]));
}
//# sourceMappingURL=signature.js.map