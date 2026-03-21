import { logger } from "../../../core/logger";
import { computeBounceRate, EmailMetricSnapshot } from "./metrics";

export function triggerDeliverabilityAlerts(metrics: EmailMetricSnapshot): void {
  const bounceRate = computeBounceRate(metrics);
  if (bounceRate > 0.05) {
    logger.warn("deliverability_bounce_rate_high", { bounceRate });
  }
  if (metrics.complained > 0) {
    logger.warn("deliverability_complaints_detected", { complained: metrics.complained });
  }
}
