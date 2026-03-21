"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
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
//# sourceMappingURL=logger.js.map