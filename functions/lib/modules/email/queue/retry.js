"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.computeRetryDelayMs = computeRetryDelayMs;
const constants_1 = require("../../../shared/constants");
function computeRetryDelayMs(attempt) {
    const idx = Math.max(0, Math.min(attempt, constants_1.EMAIL_RETRY_MINUTES.length - 1));
    return constants_1.EMAIL_RETRY_MINUTES[idx] * 60_000;
}
//# sourceMappingURL=retry.js.map