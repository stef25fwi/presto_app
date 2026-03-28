"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ValidationError = void 0;
exports.toHttpsError = toHttpsError;
const https_1 = require("firebase-functions/v2/https");
class ValidationError extends Error {
    issues;
    constructor(message, issues = [message]) {
        super(message);
        this.name = "ValidationError";
        this.issues = issues;
    }
}
exports.ValidationError = ValidationError;
function toHttpsError(error, fallbackMessage = "internal error") {
    if (error instanceof https_1.HttpsError) {
        return error;
    }
    if (error instanceof ValidationError) {
        return new https_1.HttpsError("invalid-argument", error.message, { issues: error.issues });
    }
    if (error instanceof Error) {
        return new https_1.HttpsError("internal", error.message || fallbackMessage);
    }
    return new https_1.HttpsError("internal", fallbackMessage);
}
//# sourceMappingURL=errors.js.map