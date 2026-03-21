"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.triggerDeliverabilityAlerts = triggerDeliverabilityAlerts;
const logger_1 = require("../../../core/logger");
const metrics_1 = require("./metrics");
function triggerDeliverabilityAlerts(metrics) {
    const bounceRate = (0, metrics_1.computeBounceRate)(metrics);
    if (bounceRate > 0.05) {
        logger_1.logger.warn("deliverability_bounce_rate_high", { bounceRate });
    }
    if (metrics.complained > 0) {
        logger_1.logger.warn("deliverability_complaints_detected", { complained: metrics.complained });
    }
}
//# sourceMappingURL=alerts.js.map