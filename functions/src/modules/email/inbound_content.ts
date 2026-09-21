const TRACKING_HOST_PATTERN = /(^|\.)[a-z0-9-]*sendibt\d*\.com$|(^|\.)r\.sendinblue\.com$|(^|\.)r\.brevo\.com$/i;

function decodeHtmlEntities(input: string): string {
  const named: Record<string, string> = {
    amp: "&",
    apos: "'",
    gt: ">",
    lt: "<",
    nbsp: " ",
    quot: '"',
  };
  return input.replace(
    /&(#\d+|#x[0-9a-f]+|amp|apos|gt|lt|nbsp|quot);/gi,
    (match, entity: string) => {
      if (entity[0] === "#") {
        const hex = entity[1]?.toLowerCase() === "x";
        const raw = entity.slice(hex ? 2 : 1);
        const value = Number.parseInt(raw, hex ? 16 : 10);
        if (Number.isFinite(value) && value > 0 && value <= 0x10ffff) {
          try {
            return String.fromCodePoint(value);
          } catch {
            return match;
          }
        }
        return match;
      }
      return named[entity.toLowerCase()] ?? match;
    },
  );
}

function trackingUrl(value: string): boolean {
  try {
    const parsed = new URL(value);
    return TRACKING_HOST_PATTERN.test(parsed.hostname);
  } catch {
    return false;
  }
}

function trackingLikeLabel(value: string): boolean {
  const normalized = value.trim().replace(/^https?:\/\//i, "");
  return /sendibt\d*\.com|r\.sendinblue\.com|r\.brevo\.com/i.test(normalized);
}

function removeMarkdownLinks(input: string): string {
  return input.replace(
    /!?\[([^\]]*)\]\((https?:\/\/[^)\s]+)(?:\s+["'][^"']*["'])?\)/gi,
    (_match, rawLabel: string, url: string) => {
      const label = rawLabel.trim();
      if (trackingUrl(url) && (!label || trackingLikeLabel(label))) {
        return "";
      }
      return label;
    },
  );
}

function removeTrackingUrls(input: string): string {
  return input.replace(
    /https?:\/\/[^\s<>\])}]+/gi,
    (url) => trackingUrl(url) ? "" : url,
  );
}

function normalizeLines(input: string): string {
  return input
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((line) => line.replace(/[\t ]+/g, " ").trimEnd())
    .join("\n")
    .replace(/\n[ \t]+/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export function markdownEmailToPlainText(input: string): string {
  if (!input) return "";
  let text = input.replace(/\u0000/g, "");
  text = text.replace(
    /<((?:https?:\/\/)[^>]+)>/gi,
    (_match, url: string) => trackingUrl(url) ? "" : url,
  );
  text = removeMarkdownLinks(text);
  text = removeTrackingUrls(text);
  text = text
    .replace(/^\s{0,3}#{1,6}\s+/gm, "")
    .replace(/^\s*>\s?/gm, "")
    .replace(/^\s*[-*+]\s+/gm, "• ")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/__([^_]+)__/g, "$1")
    .replace(/~~([^~]+)~~/g, "$1")
    .replace(/(?<!\*)\*([^*\n]+)\*(?!\*)/g, "$1")
    .replace(/(?<!_)_([^_\n]+)_(?!_)/g, "$1")
    .replace(/\`([^\`]+)\`/g, "$1")
    .replace(/<[^>]+>/g, "");
  return normalizeLines(decodeHtmlEntities(text));
}

export function htmlEmailToPlainText(input: string): string {
  if (!input) return "";
  let html = input.replace(/\u0000/g, "");
  html = html
    .replace(/<(script|style|head|svg)[^>]*>[\s\S]*?<\/\1>/gi, "")
    .replace(/<br\s*\/?\s*>/gi, "\n")
    .replace(/<\/(p|div|section|article|header|footer|li|tr|h[1-6])\s*>/gi, "\n")
    .replace(/<li\b[^>]*>/gi, "• ")
    .replace(/<a\b[^>]*>([\s\S]*?)<\/a>/gi, "$1")
    .replace(/<[^>]+>/g, "");
  return markdownEmailToPlainText(decodeHtmlEntities(html));
}

export function plainEmailToDisplayText(input: string): string {
  if (!input) return "";
  const withoutTracking = removeTrackingUrls(input.replace(/\u0000/g, ""));
  return normalizeLines(decodeHtmlEntities(removeMarkdownLinks(withoutTracking)));
}

export type InboundBodySource = "raw_text" | "markdown" | "html" | "none";

export function selectInboundDisplayBody(input: {
  rawText?: unknown;
  markdown?: unknown;
  html?: unknown;
  maxLength?: number;
}): { text: string; source: InboundBodySource } {
  const maxLength = Math.max(1, input.maxLength ?? 20_000);
  const rawText = typeof input.rawText === "string" ? input.rawText : "";
  const markdown = typeof input.markdown === "string" ? input.markdown : "";
  const html = typeof input.html === "string" ? input.html : "";

  const candidates: Array<{ source: InboundBodySource; text: string }> = [
    { source: "raw_text", text: plainEmailToDisplayText(rawText) },
    { source: "markdown", text: markdownEmailToPlainText(markdown) },
    { source: "html", text: htmlEmailToPlainText(html) },
  ];

  for (const candidate of candidates) {
    if (candidate.text) {
      return { text: candidate.text.slice(0, maxLength), source: candidate.source };
    }
  }
  return { text: "", source: "none" };
}

export function emailPreview(input: string, maxLength = 280): string {
  return input.replace(/\s+/g, " ").trim().slice(0, Math.max(1, maxLength));
}
