export type AppCheckDecisionInput = {
  isEmulator: boolean;
  isProduction: boolean;
  enforceValue?: unknown;
  safeModeValue?: unknown;
};

function normalizeBoolean(value: unknown): boolean {
  return String(value ?? "").trim().toLowerCase() === "true";
}

export function resolveAppCheckEnforcement({
  isEmulator,
  isProduction,
  enforceValue,
  safeModeValue,
}: AppCheckDecisionInput): boolean {
  if (isEmulator) return false;

  // Production is fail-closed: environment flags may not disable App Check.
  if (isProduction) return true;

  if (normalizeBoolean(safeModeValue)) return false;
  return normalizeBoolean(enforceValue);
}
