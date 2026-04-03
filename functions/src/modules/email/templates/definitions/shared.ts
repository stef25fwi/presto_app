import {
  EmailTemplateDefinition,
  EmailTone,
  EmailType,
} from "../../contracts";

const tonePalette: Record<EmailTone, { accent: string; eyebrow: string }> = {
  security: {
    accent: "#111827",
    eyebrow: "Securite compte",
  },
  trust: {
    accent: "#14532D",
    eyebrow: "Informations utiles",
  },
  business: {
    accent: "#1A73E8",
    eyebrow: "Facturation et abonnement",
  },
  onboarding: {
    accent: "#FF6600",
    eyebrow: "Bienvenue sur e-livre resto",
  },
  growth: {
    accent: "#0F766E",
    eyebrow: "Opportunites a ne pas manquer",
  },
};

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function buildEmailHtml({
  title,
  previewText,
  intro,
  body,
  ctaLabel,
  ctaVariable,
  secondaryLabel,
  secondaryVariable,
  footer,
  tone,
  type,
}: {
  title: string;
  previewText: string;
  intro: string;
  body: string[];
  ctaLabel?: string;
  ctaVariable?: string;
  secondaryLabel?: string;
  secondaryVariable?: string;
  footer?: string[];
  tone: EmailTone;
  type: EmailType;
}): string {
  const palette = tonePalette[tone];
  const footerLines = footer ?? [
    type === "marketing"
      ? "Vous recevez cet email car vous avez autorise les communications marketing d e-livre resto."
      : "Vous recevez cet email car il concerne l activite de votre compte e-livre resto.",
    "Si vous avez besoin d aide, repondez simplement a cet email ou rendez-vous dans l espace support.",
  ];

  const ctaBlock = ctaLabel && ctaVariable
    ? `<div style="margin:28px 0 16px 0;"><a href="{{${ctaVariable}}}" style="display:inline-block;background:${palette.accent};color:#FFFFFF;text-decoration:none;font-weight:700;padding:14px 22px;border-radius:999px;">${escapeHtml(ctaLabel)}</a></div>`
    : "";
  const secondaryBlock = secondaryLabel && secondaryVariable
    ? `<div style="margin:0 0 8px 0;"><a href="{{${secondaryVariable}}}" style="color:${palette.accent};text-decoration:none;font-weight:600;">${escapeHtml(secondaryLabel)}</a></div>`
    : "";

  return [
    "<!DOCTYPE html>",
    '<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>',
    '<body style="margin:0;padding:24px;background:#FFF7F1;font-family:Arial,sans-serif;color:#111827;">',
    '<div style="max-width:680px;margin:0 auto;background:#FFFFFF;border:1px solid #E5E7EB;border-radius:18px;padding:30px;">',
    `<div data-presto-email-branding="true" style="padding:0 0 24px 0;"><div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">${escapeHtml(previewText)}</div><img src="{{brandLogoUrl}}" alt="{{brandLogoAlt}}" width="124" style="display:block;max-width:124px;height:auto;border:0"></div>`,
    `<div style="color:${palette.accent};font-size:12px;font-weight:800;letter-spacing:0.08em;text-transform:uppercase;margin-bottom:12px;">${escapeHtml(palette.eyebrow)}</div>`,
    `<h1 style="margin:0 0 14px 0;font-size:28px;line-height:1.2;color:#111827;">${escapeHtml(title)}</h1>`,
    `<p style="margin:0 0 16px 0;font-size:16px;line-height:1.65;">${intro}</p>`,
    ...body.map((line) => `<p style="margin:0 0 16px 0;font-size:16px;line-height:1.7;color:#374151;">${line}</p>`),
    ctaBlock,
    secondaryBlock,
    '<hr style="margin:28px 0 20px 0;border:none;border-top:1px solid #E5E7EB">',
    ...footerLines.map((line) => `<p style="margin:0 0 10px 0;font-size:13px;line-height:1.6;color:#6B7280;">${line}</p>`),
    "</div></body></html>",
  ].join("");
}

export function buildEmailText({
  title,
  previewText,
  intro,
  body,
  ctaLabel,
  ctaVariable,
  secondaryLabel,
  secondaryVariable,
  footer,
}: {
  title: string;
  previewText: string;
  intro: string;
  body: string[];
  ctaLabel?: string;
  ctaVariable?: string;
  secondaryLabel?: string;
  secondaryVariable?: string;
  footer?: string[];
}): string {
  const lines = [
    "e-livre resto",
    "",
    title,
    "",
    previewText,
    "",
    intro.replace(/<[^>]+>/g, ""),
    "",
    ...body.map((line) => line.replace(/<[^>]+>/g, "")),
  ];

  if (ctaLabel && ctaVariable) {
    lines.push("", `${ctaLabel} : {{${ctaVariable}}}`);
  }
  if (secondaryLabel && secondaryVariable) {
    lines.push(`${secondaryLabel} : {{${secondaryVariable}}}`);
  }
  if (footer && footer.length > 0) {
    lines.push("", ...footer.map((line) => line.replace(/<[^>]+>/g, "")));
  }

  return `${lines.join("\n")}\n`;
}

export function defineTemplate(
  definition: EmailTemplateDefinition,
): EmailTemplateDefinition {
  return definition;
}