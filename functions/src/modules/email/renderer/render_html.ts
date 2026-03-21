export function renderHtml(templateHtml: string, data: Record<string, unknown>): string {
  let html = templateHtml;
  for (const [key, value] of Object.entries(data)) {
    const safeValue = String(value ?? "");
    html = html.replaceAll(`{{${key}}}`, safeValue);
  }
  return html;
}
