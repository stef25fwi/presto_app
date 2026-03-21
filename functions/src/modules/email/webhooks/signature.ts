export function normalizeHeaders(input: unknown): Record<string, string> {
  if (!input || typeof input !== "object") return {};
  const headers = input as Record<string, unknown>;
  return Object.fromEntries(
    Object.entries(headers)
      .filter(([, value]) => typeof value === "string")
      .map(([key, value]) => [key, String(value)]),
  );
}
