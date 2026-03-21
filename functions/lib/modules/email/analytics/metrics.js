"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.computeBounceRate = computeBounceRate;
function computeBounceRate(metrics) {
    if (metrics.sent === 0)
        return 0;
    return metrics.bounced / metrics.sent;
}
//# sourceMappingURL=metrics.js.map