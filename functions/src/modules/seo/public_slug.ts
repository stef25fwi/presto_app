export function publicSeoSlug(value: unknown, fallback: string): string {
  const normalized = String(value ?? "")
    .trim()
    .toLowerCase()
    .replaceAll("œ", "oe")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[’']/g, "-")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 72)
    .replace(/-$/g, "");

  if (normalized.length >= 3) return normalized;
  return fallback;
}
