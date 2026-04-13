"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
exports.logSanitized = logSanitized;
function log(level, message, context = {}) {
    const payload = {
        level,
        message,
        ts: new Date().toISOString(),
        ...context,
    };
    console.log(JSON.stringify(payload));
}
exports.logger = {
    info: (message, context) => log("INFO", message, context),
    warn: (message, context) => log("WARN", message, context),
    error: (message, context) => log("ERROR", message, context),
};
const PII_FIELDS = ["email", "phone", "displayName", "name", "avatarUrl", "photoURL"];
/**
 * Log structured data with PII fields automatically stripped.
 */
function logSanitized(level, message, data) {
    const sanitized = Object.fromEntries(Object.entries(data).filter(([key]) => !PII_FIELDS.includes(key)));
    exports.logger[level](message, sanitized);
}
//# sourceMappingURL=logger.js.map