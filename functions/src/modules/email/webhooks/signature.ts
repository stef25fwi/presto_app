export function normalizeHeaders(input: unknown): Record<string, string> {
  if (!input || typeof input !== "object") return {};
  const headers = input as Record<string, unknown>;
  return Object.fromEntries(
    Object.entries(headers)
      .map(([key, value]) => {
        if (typeof value === "string") return [key, value] as const;
        if (Array.isArray(value)) {
          const first = value.find((v) => typeof v === "string");
          if (typeof first === "string") return [key, first] as const;
        }
        return null;
      })
      .filter((item): item is readonly [string, string] => item !== null),
  );
}
