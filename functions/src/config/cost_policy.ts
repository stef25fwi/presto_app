export type CostEnvironment = Record<string, string | undefined>;

export type MicroIaProviderMode = "GOOGLE_ONLY" | "HYBRID" | "WHISPER_ONLY";

export interface CostPolicy {
  minimumCostMode: boolean;
  minInstances: number;
  microIaMaxInstances: number;
  microIaProviderMode: MicroIaProviderMode;
  microIaFallbackEnabled: boolean;
  microIaMonthlyAudioSeconds: number;
  openAiMonthlyRequestLimit: number;
  veoGenerationEnabled: boolean;
  veoMonthlyGenerationLimit: number;
  veoMaxInstances: number;
  verboseCostLogs: boolean;
  stripeCatalogAuditEnabled: boolean;
}

export function parseCostBoolean(
  value: string | undefined,
  fallback: boolean,
): boolean {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "off"].includes(normalized)) return false;
  return fallback;
}

export function parseCostInteger(
  value: string | undefined,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const parsed = Number(value);
  const integer = Number.isFinite(parsed) ? Math.trunc(parsed) : fallback;
  return Math.min(maximum, Math.max(minimum, integer));
}

function parseMicroIaMode(
  value: string | undefined,
  fallback: MicroIaProviderMode,
): MicroIaProviderMode {
  const normalized = String(value ?? "").trim().toUpperCase();
  if (
    normalized === "GOOGLE_ONLY" ||
    normalized === "HYBRID" ||
    normalized === "WHISPER_ONLY"
  ) {
    return normalized;
  }
  return fallback;
}

export function resolveCostPolicy(
  environment: CostEnvironment = process.env,
): CostPolicy {
  const minimumCostMode = parseCostBoolean(
    environment.MINIMUM_COST_MODE,
    true,
  );
  const requestedMinInstances = parseCostInteger(
    environment.FUNCTIONS_MIN_INSTANCES,
    0,
    0,
    10,
  );
  const requestedVeoEnabled = parseCostBoolean(
    environment.VEO_GENERATION_ENABLED,
    false,
  );

  return {
    minimumCostMode,
    minInstances: minimumCostMode ? 0 : requestedMinInstances,
    microIaMaxInstances: parseCostInteger(
      environment.MICROIA_MAX_INSTANCES,
      minimumCostMode ? 2 : 10,
      1,
      50,
    ),
    microIaProviderMode: minimumCostMode
      ? "GOOGLE_ONLY"
      : parseMicroIaMode(environment.MICROIA_PROVIDER_MODE, "GOOGLE_ONLY"),
    microIaFallbackEnabled: minimumCostMode
      ? false
      : parseCostBoolean(environment.MICROIA_FALLBACK_ENABLED, true),
    microIaMonthlyAudioSeconds: parseCostInteger(
      environment.MICROIA_MONTHLY_AUDIO_SECONDS,
      minimumCostMode ? 3600 : 21600,
      0,
      2_592_000,
    ),
    openAiMonthlyRequestLimit: parseCostInteger(
      environment.OPENAI_MONTHLY_REQUEST_LIMIT,
      minimumCostMode ? 2000 : 20000,
      0,
      1_000_000,
    ),
    veoGenerationEnabled: !minimumCostMode && requestedVeoEnabled,
    veoMonthlyGenerationLimit: parseCostInteger(
      environment.VEO_MONTHLY_GENERATION_LIMIT,
      minimumCostMode ? 0 : 20,
      0,
      1000,
    ),
    veoMaxInstances: parseCostInteger(
      environment.VEO_MAX_INSTANCES,
      1,
      1,
      3,
    ),
    verboseCostLogs: !minimumCostMode && parseCostBoolean(
      environment.COST_VERBOSE_LOGS,
      false,
    ),
    stripeCatalogAuditEnabled: !minimumCostMode && parseCostBoolean(
      environment.STRIPE_CATALOG_AUDIT_ENABLED,
      true,
    ),
  };
}

export const COST_POLICY = resolveCostPolicy();
