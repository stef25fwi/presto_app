import { logger } from "../../../core/logger";
import {
  DEFAULT_DELIVERABILITY_THRESHOLDS,
  type DeliverabilityThresholds,
} from "../certification/deliverability";
import { computeBounceRate, computeComplaintRate, EmailMetricSnapshot } from "./metrics";

export function triggerDeliverabilityAlerts(
  metrics: EmailMetricSnapshot,
  thresholds: DeliverabilityThresholds = DEFAULT_DELIVERABILITY_THRESHOLDS,
): void {
  const bounceRate = computeBounceRate(metrics);
  const complaintRate = computeComplaintRate(metrics);

  if (bounceRate > thresholds.maxBounceRate) {
    logger.warn("deliverability_bounce_rate_high", {
      bounceRate,
      threshold: thresholds.maxBounceRate,
    });
  }
  if (complaintRate > thresholds.maxComplaintRate) {
    logger.warn("deliverability_complaint_rate_high", {
      complaintRate,
      threshold: thresholds.maxComplaintRate,
    });
  }
  if (metrics.complained > 0) {
    // Sur un volume faible, une seule plainte reste sous le seuil de taux tout
    // en méritant un signal : la réputation se dégrade avant les statistiques.
    logger.warn("deliverability_complaints_detected", { complained: metrics.complained });
  }
}
