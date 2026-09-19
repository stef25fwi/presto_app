import { createHash } from "node:crypto";

export interface PublicServiceProfile {
  publicId: string;
  visibility: string;
  seoEligible: boolean;
  verified: boolean;
  companyName: string;
  activity: string;
  description: string;
  serviceCategories: string;
  interventionZone: string;
  city: string;
  postalCode: string;
  website: string;
  publishedAt: string | null;
  updatedAt: string | null;
}

const BASE_URL = "https://ilipresto.fr";
const SAFE_PUBLIC_ID = /^[a-f0-9]{24}$/;

function boundedText(value: unknown, maxLength: number): string {
  return String(value ?? "")
    .replace(/[\u0000-\u001F\u007F]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function timestampToIso(value: unknown): string | null {
  if (value && typeof value === "object" && "toDate" in value) {
    const candidate = value as { toDate?: () => Date };
    if (typeof candidate.toDate === "function") {
      const date = candidate.toDate();
      if (!Number.isNaN(date.getTime())) return date.toISOString();
    }
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString();
  }
  const raw = boundedText(value, 64);
  if (!raw) return null;
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function jsonForHtml(value: unknown): string {
  return JSON.stringify(value)
    .replaceAll("<", "\\u003c")
    .replaceAll(">", "\\u003e")
    .replaceAll("&", "\\u0026");
}

function descriptionSnippet(value: string): string {
  if (value.length <= 158) return value;
  const slice = value.slice(0, 155).trimEnd();
  const lastSpace = slice.lastIndexOf(" ");
  const base = lastSpace >= 120 ? slice.slice(0, lastSpace) : slice;
  return `${base}...`;
}

function normalizeWebsite(value: unknown): string {
  const raw = boundedText(value, 300);
  if (!raw) return "";
  try {
    const url = new URL(raw);
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : "";
  } catch (_) {
    return "";
  }
}

export function publicProfileIdForUid(uid: string): string {
  return createHash("sha256")
    .update(`${uid}:ilipresto-public-profile-v1`, "utf8")
    .digest("hex")
    .slice(0, 24);
}

export type SourceProfilePublicEligibilityReason =
  | "consent_missing"
  | "siret_unverified"
  | "establishment_inactive"
  | "company_name_too_short"
  | "activity_too_short"
  | "description_too_short"
  | "service_categories_missing"
  | "city_missing";

export function sourceProfilePublicEligibilityReasons(
  data: Record<string, unknown>,
): SourceProfilePublicEligibilityReason[] {
  const reasons: SourceProfilePublicEligibilityReason[] = [];
  if (data.seoPublicProfileConsent !== true) reasons.push("consent_missing");
  if (data.siretVerified !== true) reasons.push("siret_unverified");
  if (data.establishmentActive === false) reasons.push("establishment_inactive");
  if (boundedText(data.companyName, 140).length < 2) reasons.push("company_name_too_short");
  if (boundedText(data.activity, 140).length < 3) reasons.push("activity_too_short");
  if (boundedText(data.description, 2000).length < 80) reasons.push("description_too_short");
  if (boundedText(data.serviceCategories, 400).length < 2) reasons.push("service_categories_missing");
  if (boundedText(data.city, 120).length < 2) reasons.push("city_missing");
  return reasons;
}

export function sourceProfileIsPublicEligible(data: Record<string, unknown>): boolean {
  return sourceProfilePublicEligibilityReasons(data).length === 0;
}

export function buildPublicProfileProjection(
  uid: string,
  data: Record<string, unknown>,
): Omit<PublicServiceProfile, "publishedAt" | "updatedAt"> {
  return {
    publicId: publicProfileIdForUid(uid),
    visibility: "public",
    seoEligible: true,
    verified: true,
    companyName: boundedText(data.companyName, 140),
    activity: boundedText(data.activity, 140),
    description: boundedText(data.description, 2000),
    serviceCategories: boundedText(data.serviceCategories, 400),
    interventionZone: boundedText(data.interventionZone, 300),
    city: boundedText(data.city, 120),
    postalCode: boundedText(data.postalCode, 16),
    website: normalizeWebsite(data.website),
  };
}

export function normalizePublicProfile(
  id: unknown,
  data: Record<string, unknown>,
): PublicServiceProfile {
  return {
    publicId: boundedText(id, 64),
    visibility: boundedText(data.visibility, 32).toLowerCase(),
    seoEligible: data.seoEligible === true,
    verified: data.verified === true,
    companyName: boundedText(data.companyName, 140),
    activity: boundedText(data.activity, 140),
    description: boundedText(data.description, 2000),
    serviceCategories: boundedText(data.serviceCategories, 400),
    interventionZone: boundedText(data.interventionZone, 300),
    city: boundedText(data.city, 120),
    postalCode: boundedText(data.postalCode, 16),
    website: normalizeWebsite(data.website),
    publishedAt: timestampToIso(data.publishedAt),
    updatedAt: timestampToIso(data.updatedAt),
  };
}

export function isIndexablePublicProfile(profile: PublicServiceProfile): boolean {
  return SAFE_PUBLIC_ID.test(profile.publicId)
    && profile.visibility === "public"
    && profile.seoEligible
    && profile.verified
    && profile.companyName.length >= 2
    && profile.activity.length >= 3
    && profile.description.length >= 80
    && profile.serviceCategories.length >= 2
    && profile.city.length >= 2;
}

export function publicProfileRoute(publicId: string): string {
  if (!SAFE_PUBLIC_ID.test(publicId)) throw new Error("invalid_public_profile_id");
  return `/prestataires/${publicId}/`;
}

export function publicProfileCanonical(publicId: string): string {
  return `${BASE_URL}${publicProfileRoute(publicId)}`;
}

export function extractPublicProfileId(pathname: string): string | null {
  const match = pathname.match(/^\/prestataires\/([a-f0-9]{24})\/?$/);
  return match?.[1] ?? null;
}

export function renderPublicProfileHtml(profile: PublicServiceProfile): string {
  const canonical = publicProfileCanonical(profile.publicId);
  const title = `${profile.companyName} – ${profile.activity} à ${profile.city} | iliprestō`.slice(0, 70);
  const metaDescription = descriptionSnippet(
    `${profile.companyName} à ${profile.city}. ${profile.description}`,
  );
  const graph = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "ProfilePage",
        "@id": `${canonical}#profilepage`,
        url: canonical,
        name: title,
        description: metaDescription,
        inLanguage: "fr-FR",
        isPartOf: { "@id": `${BASE_URL}/#website` },
        publisher: { "@id": `${BASE_URL}/#organization` },
        mainEntity: { "@id": `${canonical}#provider` },
        ...(profile.publishedAt ? { dateCreated: profile.publishedAt } : {}),
        ...(profile.updatedAt ? { dateModified: profile.updatedAt } : {}),
      },
      {
        "@type": "Organization",
        "@id": `${canonical}#provider`,
        name: profile.companyName,
        description: profile.description,
        knowsAbout: profile.serviceCategories,
        areaServed: {
          "@type": "City",
          name: profile.city,
        },
        ...(profile.website ? { url: profile.website } : {}),
      },
      {
        "@type": "BreadcrumbList",
        "@id": `${canonical}#breadcrumb`,
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Accueil", item: `${BASE_URL}/` },
          { "@type": "ListItem", position: 2, name: "Services", item: `${BASE_URL}/services/` },
          { "@type": "ListItem", position: 3, name: profile.companyName, item: canonical },
        ],
      },
    ],
  };

  const websiteLink = profile.website
    ? `<a href="${escapeHtml(profile.website)}" rel="noopener noreferrer nofollow">Site professionnel</a>`
    : "";

  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="description" content="${escapeHtml(metaDescription)}">
  <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
  <meta name="theme-color" content="#FF6600">
  <link rel="canonical" href="${canonical}">
  <link rel="alternate" hreflang="fr-FR" href="${canonical}">
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/public-pages.css">
  <meta property="og:type" content="profile">
  <meta property="og:locale" content="fr_FR">
  <meta property="og:site_name" content="iliprestō">
  <meta property="og:url" content="${canonical}">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(metaDescription)}">
  <meta property="og:image" content="${BASE_URL}/icons/Icon-512.png">
  <title>${escapeHtml(title)}</title>
  <script type="application/ld+json">${jsonForHtml(graph)}</script>
</head>
<body class="public-page">
  <div class="public-shell">
    <header><a class="public-brand" href="/" aria-label="Accueil iliprestō"><img src="/assets/assets/images/ilipresto_splash_logo.webp" alt="Logo iliprestō" width="54" height="54"><span>iliprestō</span></a></header>
    <nav class="public-breadcrumb" aria-label="Fil d’Ariane"><ol><li><a href="/">Accueil</a></li><li><a href="/services/">Services</a></li><li aria-current="page">${escapeHtml(profile.companyName)}</li></ol></nav>
    <main class="public-card">
      <span class="public-kicker">Professionnel vérifié · ${escapeHtml(profile.city)}${profile.postalCode ? ` · ${escapeHtml(profile.postalCode)}` : ""}</span>
      <h1>${escapeHtml(profile.companyName)}</h1>
      <p class="public-lead">${escapeHtml(profile.activity)}</p>
      <section class="public-grid" aria-label="Profil professionnel">
        <article><h2>Activité</h2><p>${escapeHtml(profile.activity)}</p></article>
        <article><h2>Services</h2><p>${escapeHtml(profile.serviceCategories)}</p></article>
        <article><h2>Zone d’intervention</h2><p>${escapeHtml(profile.interventionZone || profile.city)}</p></article>
      </section>
      <section><h2>Présentation</h2><p>${escapeHtml(profile.description)}</p></section>
      <nav class="public-links" aria-label="Explorer iliprestō">
        ${websiteLink}
        <a href="/services/">Explorer les services</a>
        <a href="/annonces-services/">Voir les annonces de services</a>
      </nav>
    </main>
    <footer class="public-footer"><span>ilipresto.fr — Profil professionnel public</span><a href="/mentions-legales">Mentions légales</a><a href="/confidentialite">Confidentialité</a><a href="/cgu">Conditions d’utilisation</a></footer>
  </div>
</body>
</html>`;
}

export function renderMissingPublicProfileHtml(): string {
  return '<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="robots" content="noindex,follow"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Profil indisponible | iliprestō</title></head><body><main><h1>Profil indisponible</h1><p>Ce profil professionnel n’est plus public ou n’existe pas.</p><a href="/services/">Explorer les services</a></main></body></html>';
}

export function renderPublicProfilesSitemap(profiles: PublicServiceProfile[]): string {
  const urls = profiles
    .filter(isIndexablePublicProfile)
    .sort((a, b) => a.publicId.localeCompare(b.publicId))
    .map((profile) => {
      const lastmod = profile.updatedAt ?? profile.publishedAt;
      return [
        "  <url>",
        `    <loc>${publicProfileCanonical(profile.publicId)}</loc>`,
        ...(lastmod ? [`    <lastmod>${lastmod.slice(0, 10)}</lastmod>`] : []),
        "    <changefreq>weekly</changefreq>",
        "  </url>",
      ].join("\n");
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}${urls ? "\n" : ""}</urlset>\n`;
}
