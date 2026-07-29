"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
exports.sanitizeLogContext = sanitizeLogContext;
exports.logSanitized = logSanitized;
const SENSITIVE_KEY_PATTERN = /(?:email|phone|displayname|name|avatarurl|photourl|prompt|content|transcript|transcription|audiobase64|imagebase64|base64|authorization|token|secret|password)/i;
const MAX_LOG_STRING_LENGTH = 500;
function sanitizeValue(value, depth = 0) {
    if (depth > 5)
        return "[TRUNCATED_DEPTH]";
    if (typeof value === "string") {
        return value.length > MAX_LOG_STRING_LENGTH
            ? `${value.slice(0, MAX_LOG_STRING_LENGTH)}…[TRUNCATED]`
            : value;
    }
    if (Array.isArray(value)) {
        return value.slice(0, 50).map((item) => sanitizeValue(item, depth + 1));
    }
    if (value && typeof value === "object") {
        return Object.fromEntries(Object.entries(value)
            .filter(([key]) => !SENSITIVE_KEY_PATTERN.test(key))
            .map(([key, item]) => [key, sanitizeValue(item, depth + 1)]));
    }
    return value;
}
function sanitizeLogContext(context = {}) {
    return sanitizeValue(context);
}
function log(level, message, context = {}) {
    const payload = {
        level,
        message,
        ts: new Date().toISOString(),
        ...sanitizeLogContext(context),
    };
    console.log(JSON.stringify(payload));
}
exports.logger = {
    info: (message, context) => log("INFO", message, context),
    warn: (message, context) => log("WARN", message, context),
    error: (message, context) => log("ERROR", message, context),
};
/**
 * Backward-compatible explicit sanitizer. The base logger now applies the same
 * recursive redaction to every structured log entry.
 */
function logSanitized(level, message, data) {
    exports.logger[level](message, data);
}
//# sourceMappingURL=logger.js.map