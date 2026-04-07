export function renderText(templateText: string, data: Record<string, unknown>): string {
  let text = templateText;
  for (const [key, value] of Object.entries(data)) {
    const safeValue = String(value ?? "");
    text = text.replaceAll(`{{${key}}}`, safeValue);
  }
  return text;
}
