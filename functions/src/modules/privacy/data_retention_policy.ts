export type RetentionCategory =
  | "operational"
  | "security_audit"
  | "business_record"
  | "user_content";

export type RetentionPolicyEntry = {
  collection: string;
  timestampField: string;
  retentionDays: number;
  category: RetentionCategory;
  reason: string;
  requiresLegalValidation?: boolean;
};

export const DATA_RETENTION_POLICY_VERSION = 1;

export const DATA_RETENTION_POLICIES: readonly RetentionPolicyEntry[] = [
  {
    collection: "app_monitoring_events",
    timestampField: "createdAt",
    retentionDays: 90,
    category: "operational",
    reason: "Diagnostic applicatif et analyse des incidents récents.",
  },
  {
    collection: "notifications",
    timestampField: "createdAt",
    retentionDays: 90,
    category: "operational",
    reason: "Historique utilisateur borné des notifications.",
  },
  {
    collection: "email_logs",
    timestampField: "createdAt",
    retentionDays: 180,
    category: "operational",
    reason: "Diagnostic de délivrabilité et support email.",
  },
  {
    collection: "adminActions",
    timestampField: "createdAt",
    retentionDays: 365,
    category: "security_audit",
    reason: "Traçabilité des actions administratives sensibles.",
    requiresLegalValidation: true,
  },
  {
    collection: "deletedListings",
    timestampField: "deletedAt",
    retentionDays: 365,
    category: "security_audit",
    reason: "Historique des annonces supprimées et résolution des litiges.",
    requiresLegalValidation: true,
  },
  {
    collection: "billing_invoices",
    timestampField: "createdAt",
    retentionDays: 3650,
    category: "business_record",
    reason: "Conservation comptable et fiscale longue durée.",
    requiresLegalValidation: true,
  },
] as const;

export type RetentionRuntimeConfig = {
  purgeEnabled: boolean;
  dryRun: boolean;
  batchSize: number;
};

export type RetentionPlanEntry = RetentionPolicyEntry & {
  cutoffIso: string;
};

export function resolveRetentionRuntimeConfig(
  environment: Record<string, string | undefined>,
): RetentionRuntimeConfig {
  const purgeEnabled = normalizeBoolean(environment.RETENTION_PURGE_ENABLED);
  const explicitDryRun = environment.RETENTION_PURGE_DRY_RUN;
  const dryRun = explicitDryRun == null
    ? true
    : normalizeBoolean(explicitDryRun);
  const requestedBatchSize = Number(environment.RETENTION_PURGE_BATCH_SIZE || 200);
  const batchSize = Number.isInteger(requestedBatchSize)
    ? Math.min(400, Math.max(1, requestedBatchSize))
    : 200;

  return {
    purgeEnabled,
    dryRun: !purgeEnabled || dryRun,
    batchSize,
  };
}

export function buildRetentionPlan(
  now: Date,
  policies: readonly RetentionPolicyEntry[] = DATA_RETENTION_POLICIES,
): RetentionPlanEntry[] {
  if (Number.isNaN(now.getTime())) {
    throw new TypeError("now must be a valid Date");
  }

  return policies.map((policy) => ({
    ...policy,
    cutoffIso: retentionCutoff(now, policy.retentionDays).toISOString(),
  }));
}

export function retentionCutoff(now: Date, retentionDays: number): Date {
  if (!Number.isInteger(retentionDays) || retentionDays <= 0) {
    throw new RangeError("retentionDays must be a positive integer");
  }
  return new Date(now.getTime() - retentionDays * 24 * 60 * 60 * 1000);
}

export function isExpiredForRetention({
  value,
  cutoff,
}: {
  value: Date | string | number | null | undefined;
  cutoff: Date;
}): boolean {
  if (Number.isNaN(cutoff.getTime()) || value == null) return false;
  const candidate = value instanceof Date ? value : new Date(value);
  return !Number.isNaN(candidate.getTime()) && candidate.getTime() < cutoff.getTime();
}

function normalizeBoolean(value: string | undefined): boolean {
  return String(value ?? "").trim().toLowerCase() === "true";
}
