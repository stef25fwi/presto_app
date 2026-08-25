/**
 * Seuils internes de délivrabilité et évaluation d'un échantillon d'envois.
 *
 * Source unique partagée entre l'alerting runtime (`analytics/alerts`) et la
 * certification CI, pour qu'un seuil ne puisse pas dériver entre les deux.
 */

export interface DeliverabilityStats {
  /** Nombre d'envois acceptés par le fournisseur (`requests` chez Brevo). */
  readonly requests: number;
  readonly delivered: number;
  readonly hardBounces: number;
  readonly softBounces: number;
  readonly blocked: number;
  readonly spamReports: number;
  readonly invalid: number;
  readonly deferred: number;
  readonly unsubscribed: number;
}

export interface DeliverabilityThresholds {
  /** En dessous de ce volume, les taux ne sont pas statistiquement exploitables. */
  readonly minSample: number;
  readonly minDeliveryRate: number;
  readonly maxHardBounceRate: number;
  readonly maxSoftBounceRate: number;
  readonly maxBounceRate: number;
  readonly maxBlockedRate: number;
  readonly maxComplaintRate: number;
  readonly maxInvalidRate: number;
  readonly maxDeferredRate: number;
}

export interface DeliverabilityRates {
  readonly delivery: number;
  readonly hardBounce: number;
  readonly softBounce: number;
  readonly bounce: number;
  readonly blocked: number;
  readonly complaint: number;
  readonly invalid: number;
  readonly deferred: number;
}

export interface DeliverabilityViolation {
  readonly metric: keyof DeliverabilityRates;
  readonly rate: number;
  readonly threshold: number;
  readonly direction: "max" | "min";
}

export interface DeliverabilityEvaluation {
  readonly ok: boolean;
  /** false quand le volume est trop faible : les seuils ne sont pas appliqués. */
  readonly evaluated: boolean;
  readonly sample: number;
  readonly rates: DeliverabilityRates;
  readonly violations: readonly DeliverabilityViolation[];
  readonly warnings: readonly string[];
  readonly thresholds: DeliverabilityThresholds;
}

/**
 * Valeurs de départ iliprestō. Le taux de plainte reste très en dessous des
 * 0,3 % sanctionnés par Gmail et Yahoo, pour garder une marge d'alerte utile.
 */
export const DEFAULT_DELIVERABILITY_THRESHOLDS: DeliverabilityThresholds = {
  minSample: 50,
  minDeliveryRate: 0.95,
  maxHardBounceRate: 0.02,
  maxSoftBounceRate: 0.05,
  maxBounceRate: 0.05,
  maxBlockedRate: 0.02,
  maxComplaintRate: 0.001,
  maxInvalidRate: 0.01,
  maxDeferredRate: 0.1,
};

function rate(numerator: number, denominator: number): number {
  if (denominator <= 0) return 0;
  return numerator / denominator;
}

export function computeDeliverabilityRates(stats: DeliverabilityStats): DeliverabilityRates {
  const sample = Math.max(0, stats.requests);
  const bounces = stats.hardBounces + stats.softBounces;
  return {
    delivery: rate(stats.delivered, sample),
    hardBounce: rate(stats.hardBounces, sample),
    softBounce: rate(stats.softBounces, sample),
    bounce: rate(bounces, sample),
    blocked: rate(stats.blocked, sample),
    complaint: rate(stats.spamReports, sample),
    invalid: rate(stats.invalid, sample),
    deferred: rate(stats.deferred, sample),
  };
}

export function evaluateDeliverability(
  stats: DeliverabilityStats,
  thresholds: DeliverabilityThresholds = DEFAULT_DELIVERABILITY_THRESHOLDS,
): DeliverabilityEvaluation {
  const sample = Math.max(0, stats.requests);
  const rates = computeDeliverabilityRates(stats);
  const warnings: string[] = [];

  if (sample < thresholds.minSample) {
    // Un seul hard bounce sur cinq envois dépasserait tous les seuils : on
    // remonte l'échantillon insuffisant sans faire échouer la certification.
    warnings.push("sample_below_threshold");
    if (stats.hardBounces > 0) warnings.push("hard_bounce_observed");
    if (stats.spamReports > 0) warnings.push("complaint_observed");
    if (stats.blocked > 0) warnings.push("blocked_observed");
    return { ok: true, evaluated: false, sample, rates, violations: [], warnings, thresholds };
  }

  const violations: DeliverabilityViolation[] = [];
  const maxChecks: readonly (readonly [keyof DeliverabilityRates, number])[] = [
    ["hardBounce", thresholds.maxHardBounceRate],
    ["softBounce", thresholds.maxSoftBounceRate],
    ["bounce", thresholds.maxBounceRate],
    ["blocked", thresholds.maxBlockedRate],
    ["complaint", thresholds.maxComplaintRate],
    ["invalid", thresholds.maxInvalidRate],
    ["deferred", thresholds.maxDeferredRate],
  ];

  for (const [metric, threshold] of maxChecks) {
    if (rates[metric] > threshold) {
      violations.push({ metric, rate: rates[metric], threshold, direction: "max" });
    }
  }
  if (rates.delivery < thresholds.minDeliveryRate) {
    violations.push({
      metric: "delivery",
      rate: rates.delivery,
      threshold: thresholds.minDeliveryRate,
      direction: "min",
    });
  }

  return {
    ok: violations.length === 0,
    evaluated: true,
    sample,
    rates,
    violations,
    warnings,
    thresholds,
  };
}

export function describeViolation(violation: DeliverabilityViolation): string {
  const percent = (value: number): string => `${(value * 100).toFixed(3)}%`;
  const comparator = violation.direction === "max" ? ">" : "<";
  return `${violation.metric} ${percent(violation.rate)} ${comparator} ${percent(violation.threshold)}`;
}
