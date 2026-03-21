"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppError = void 0;
class AppError extends Error {
    code;
    retryable;
    constructor(message, code, retryable = false) {
        super(message);
        this.code = code;
        this.retryable = retryable;
        this.name = "AppError";
    }
}
exports.AppError = AppError;
//# sourceMappingURL=errors.js.map