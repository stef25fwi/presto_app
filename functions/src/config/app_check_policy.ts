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
  if (normalizeBoolean(safeModeValue)) return false;

  const normalizedEnforce = String(enforceValue ?? "")
    .trim()
    .toLowerCase();

  if (isProduction) {
    return normalizedEnforce !== "false";
  }
  return normalizedEnforce === "true";
}
