export interface EmailMetricSnapshot {
  sent: number;
  delivered: number;
  bounced: number;
  complained: number;
  failed: number;
}

export function computeBounceRate(metrics: EmailMetricSnapshot): number {
  if (metrics.sent === 0) return 0;
  return metrics.bounced / metrics.sent;
}

export function computeComplaintRate(metrics: EmailMetricSnapshot): number {
  if (metrics.sent === 0) return 0;
  return metrics.complained / metrics.sent;
}
