"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeHeaders = normalizeHeaders;
function normalizeHeaders(input) {
    if (!input || typeof input !== "object")
        return {};
    const headers = input;
    return Object.fromEntries(Object.entries(headers)
        .map(([key, value]) => {
        if (typeof value === "string")
            return [key, value];
        if (Array.isArray(value)) {
            const first = value.find((v) => typeof v === "string");
            if (typeof first === "string")
                return [key, first];
        }
        return null;
    })
        .filter((item) => item !== null));
}
//# sourceMappingURL=signature.js.map