const EMAIL_BRANDING_MARKER = "data-presto-email-branding";

function buildBrandingBlock(preheader: string): string {
  const safePreheader = preheader.trim();

  return (
    `<div ${EMAIL_BRANDING_MARKER}="true" style="padding:0 0 24px 0">` +
    `<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">${safePreheader}</div>` +
    `<img src="{{brandLogoUrl}}" alt="{{brandLogoAlt}}" width="124" style="display:block;max-width:124px;height:auto;border:0;outline:none;text-decoration:none">` +
    `</div>`
  );
}

function buildBrandedDocument(bodyHtml: string, preheader: string): string {
  return (
    `<!DOCTYPE html><html><head><meta charset="UTF-8"></head>` +
    `<body style="font-family:Arial,sans-serif;max-width:640px;margin:auto;padding:24px;color:#111827;background-color:#FFFFFF">` +
    `<div style="padding:24px;border:1px solid #E5E7EB;border-radius:16px;background-color:#FFFFFF">` +
    `${buildBrandingBlock(preheader)}` +
    `${bodyHtml}` +
    `</div></body></html>`
  );
}

export function applyFirestoreEmailBranding(templateHtml: string, preheader: string): string {
  const normalizedHtml = templateHtml.trim();

  if (!normalizedHtml) {
    return buildBrandedDocument("", preheader);
  }

  if (
    normalizedHtml.includes(EMAIL_BRANDING_MARKER) ||
    normalizedHtml.includes("{{brandLogoUrl}}") ||
    /logowebp\.webp/i.test(normalizedHtml)
  ) {
    return normalizedHtml;
  }

  if (/<body[^>]*>/i.test(normalizedHtml)) {
    return normalizedHtml.replace(
      /<body([^>]*)>/i,
      `<body$1>${buildBrandingBlock(preheader)}`,
    );
  }

  return buildBrandedDocument(normalizedHtml, preheader);
}