export interface PublicListingProjection {
  id: string;
  status: string;
  visibility: string;
  title: string;
  description: string;
  category: string;
  categoryId: string;
  city: string;
  postalCode: string;
  publishedAt: string | null;
  createdAt: string | null;
}

const BASE_URL = "https://ilipresto.fr";
const SAFE_ID = /^[A-Za-z0-9_-]{6,128}$/;

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
  return `${lastSpace >= 120 ? slice.slice(0, lastSpace) : slice}…`;
}

function formatDate(value: string | null): string {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    timeZone: "Europe/Paris",
  }).format(date);
}

export function normalizePublicListingProjection(
  id: unknown,
  data: Record<string, unknown>,
): PublicListingProjection {
  return {
    id: boundedText(id, 128),
    status: boundedText(data.status, 32).toLowerCase(),
    visibility: boundedText(data.visibility, 32).toLowerCase(),
    title: boundedText(data.title, 140),
    description: boundedText(data.description, 2_000),
    category: boundedText(data.category ?? data.categoryId, 120),
    categoryId: boundedText(data.categoryId, 120),
    city: boundedText(data.city ?? data.location, 120),
    postalCode: boundedText(data.postalCode ?? data.cp, 16),
    publishedAt: timestampToIso(data.publishedAt),
    createdAt: timestampToIso(data.createdAt),
  };
}

export function isPublicListing(listing: PublicListingProjection): boolean {
  return listing.status === "active" && listing.visibility === "public";
}

export function isSeoEligiblePublicListing(listing: PublicListingProjection): boolean {
  return isPublicListing(listing)
    && SAFE_ID.test(listing.id)
    && listing.title.length >= 12
    && listing.description.length >= 80
    && listing.category.length >= 2
    && listing.city.length >= 2;
}

export function publicListingRoute(id: string): string {
  if (!SAFE_ID.test(id)) throw new Error("invalid_public_listing_id");
  return `/annonces/${id}/`;
}

export function publicListingCanonical(id: string): string {
  return `${BASE_URL}${publicListingRoute(id)}`;
}

export function extractPublicListingId(pathname: string): string | null {
  const match = pathname.match(/^\/annonces\/([A-Za-z0-9_-]{6,128})\/?$/);
  return match?.[1] ?? null;
}

export function renderPublicListingHtml(
  listing: PublicListingProjection,
  options: { indexable?: boolean } = {},
): string {
  const canonical = publicListingCanonical(listing.id);
  const indexable = options.indexable ?? isSeoEligiblePublicListing(listing);
  const robots = indexable
    ? "index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1"
    : "noindex,follow";
  const title = `${listing.title} à ${listing.city} | iliprestō`.slice(0, 70);
  const metaDescription = descriptionSnippet(
    `${listing.title} à ${listing.city}. ${listing.description}`,
  );
  const publicationIso = listing.publishedAt ?? listing.createdAt;
  const publicationLabel = formatDate(publicationIso);
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        "@id": `${canonical}#webpage`,
        url: canonical,
        name: title,
        description: metaDescription,
        inLanguage: "fr-FR",
        isPartOf: { "@id": `${BASE_URL}/#website` },
        publisher: { "@id": `${BASE_URL}/#organization` },
        breadcrumb: { "@id": `${canonical}#breadcrumb` },
        ...(publicationIso ? { datePublished: publicationIso } : {}),
      },
      {
        "@type": "BreadcrumbList",
        "@id": `${canonical}#breadcrumb`,
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Accueil", item: `${BASE_URL}/` },
          { "@type": "ListItem", position: 2, name: "Annonces de services", item: `${BASE_URL}/annonces-services/` },
          { "@type": "ListItem", position: 3, name: listing.title, item: canonical },
        ],
      },
    ],
  };

  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="description" content="${escapeHtml(metaDescription)}">
  <meta name="robots" content="${robots}">
  <meta name="theme-color" content="#FF6600">
  <link rel="canonical" href="${canonical}">
  <link rel="alternate" hreflang="fr-FR" href="${canonical}">
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/public-pages.css">
  <meta property="og:type" content="website">
  <meta property="og:locale" content="fr_FR">
  <meta property="og:site_name" content="iliprestō">
  <meta property="og:url" content="${canonical}">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(metaDescription)}">
  <meta property="og:image" content="${BASE_URL}/icons/Icon-512.png">
  <meta property="og:image:alt" content="Logo iliprestō">
  <title>${escapeHtml(title)}</title>
  <script type="application/ld+json">${jsonForHtml(jsonLd)}</script>
</head>
<body class="public-page">
  <div class="public-shell">
    <header><a class="public-brand" href="/" aria-label="Accueil iliprestō"><img src="/assets/assets/images/ilipresto_splash_logo.webp" alt="Logo iliprestō" width="54" height="54"><span>iliprestō</span></a></header>
    <nav class="public-breadcrumb" aria-label="Fil d’Ariane"><ol><li><a href="/">Accueil</a></li><li><a href="/annonces-services/">Annonces de services</a></li><li aria-current="page">${escapeHtml(listing.title)}</li></ol></nav>
    <main class="public-card">
      <span class="public-kicker">${escapeHtml(listing.category)} · ${escapeHtml(listing.city)}${listing.postalCode ? ` · ${escapeHtml(listing.postalCode)}` : ""}</span>
      <h1>${escapeHtml(listing.title)}</h1>
      ${publicationLabel ? `<p class="public-status">Annonce publiée le ${escapeHtml(publicationLabel)}.</p>` : ""}
      <p class="public-lead">${escapeHtml(listing.description)}</p>
      <section class="public-grid" aria-label="Informations sur l’annonce">
        <article><h2>Catégorie</h2><p>${escapeHtml(listing.category)}</p></article>
        <article><h2>Localisation</h2><p>${escapeHtml(listing.city)}${listing.postalCode ? ` (${escapeHtml(listing.postalCode)})` : ""}</p></article>
        <article><h2>0 % de commission</h2><p>iliprestō ne prélève aucune commission sur vos prestations et ne collecte ni ne gère les paiements entre utilisateurs. Vous échangez et convenez directement des conditions de la mission.</p></article>
      </section>
      <nav class="public-links" aria-label="Actions et navigation"><a href="/listings/${encodeURIComponent(listing.id)}">Ouvrir cette annonce dans iliprestō</a><a href="/annonces-services/">Voir les annonces de services</a><a href="/services-et-microservices/">Explorer les services</a><a href="/jobs-et-missions/">Jobs et missions de service</a></nav>
    </main>
    <footer class="public-footer"><span>ilipresto.fr — Annonce de service</span><a href="/mentions-legales">Mentions légales</a><a href="/confidentialite">Confidentialité</a><a href="/cgu">Conditions d’utilisation</a></footer>
  </div>
</body>
</html>`;
}

export function renderMissingPublicListingHtml(): string {
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="robots" content="noindex,follow"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Annonce indisponible | iliprestō</title></head><body><main><h1>Annonce indisponible</h1><p>Cette annonce n’est plus publique ou n’existe pas.</p><a href="/annonces-services/">Voir les annonces de services</a></main></body></html>`;
}

export function renderPublicListingsSitemap(listings: PublicListingProjection[]): string {
  const urls = listings
    .filter(isSeoEligiblePublicListing)
    .sort((a, b) => a.id.localeCompare(b.id))
    .map((listing) => {
      const lastmod = listing.publishedAt ?? listing.createdAt;
      return [
        "  <url>",
        `    <loc>${publicListingCanonical(listing.id)}</loc>`,
        ...(lastmod ? [`    <lastmod>${lastmod.slice(0, 10)}</lastmod>`] : []),
        "    <changefreq>daily</changefreq>",
        "  </url>",
      ].join("\n");
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}${urls ? "\n" : ""}</urlset>\n`;
}
