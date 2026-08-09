import { FieldPath } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";

import { PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import {
  extractPublicListingId,
  isPublicListing,
  isSeoEligiblePublicListing,
  normalizePublicListingProjection,
  publicListingCanonical,
  renderMissingPublicListingHtml,
  renderPublicListingHtml,
  renderPublicListingsSitemap,
  type PublicListingProjection,
} from "./public_marketplace_core";

const PUBLIC_LISTING_FIELDS = [
  "status",
  "visibility",
  "title",
  "description",
  "category",
  "categoryId",
  "city",
  "location",
  "postalCode",
  "cp",
  "publishedAt",
  "createdAt",
] as const;

interface SeoHeaderResponse {
  set(field: string, value?: string): unknown;
}

function applySeoHeaders(res: SeoHeaderResponse): void {
  res.set("X-Content-Type-Options", "nosniff");
  res.set("Referrer-Policy", "strict-origin-when-cross-origin");
  res.set("X-Robots-Tag", "all");
}

async function loadPublicListing(listingId: string): Promise<PublicListingProjection | null> {
  const snapshot = await db
    .collection("listings")
    .where(FieldPath.documentId(), "==", listingId)
    .select(...PUBLIC_LISTING_FIELDS)
    .limit(1)
    .get();
  const document = snapshot.docs.at(0);
  if (!document) return null;
  return normalizePublicListingProjection(document.id, document.data());
}

async function loadPublicListingsForSitemap(): Promise<PublicListingProjection[]> {
  const snapshot = await db
    .collection("listings")
    .where("status", "==", "active")
    .where("visibility", "==", "public")
    .select(...PUBLIC_LISTING_FIELDS)
    .limit(50_000)
    .get();

  return snapshot.docs.map((document) =>
    normalizePublicListingProjection(document.id, document.data()),
  );
}

export const publicMarketplaceSeo = onRequest(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 10,
    memory: "256MiB",
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (req, res) => {
    applySeoHeaders(res);

    if (req.method !== "GET" && req.method !== "HEAD") {
      res.status(405).set("Allow", "GET, HEAD").send("");
      return;
    }

    try {
      if (req.path === "/sitemap-annonces.xml") {
        const listings = await loadPublicListingsForSitemap();
        const sitemap = renderPublicListingsSitemap(listings);
        res.set("Content-Type", "application/xml; charset=utf-8");
        res.set("Cache-Control", "public, max-age=300, s-maxage=900, stale-while-revalidate=1800");
        if (req.method === "HEAD") {
          res.status(200).send("");
          return;
        }
        res.status(200).send(sitemap);
        return;
      }

      const listingId = extractPublicListingId(req.path);
      if (!listingId) {
        res.set("Content-Type", "text/html; charset=utf-8");
        res.set("X-Robots-Tag", "noindex, follow");
        res.set("Cache-Control", "no-store");
        res.status(404).send(req.method === "HEAD" ? "" : renderMissingPublicListingHtml());
        return;
      }

      const canonical = publicListingCanonical(listingId);
      if (!req.path.endsWith("/")) {
        res.redirect(301, canonical);
        return;
      }

      const listing = await loadPublicListing(listingId);
      if (!listing || !isPublicListing(listing)) {
        res.set("Content-Type", "text/html; charset=utf-8");
        res.set("X-Robots-Tag", "noindex, follow");
        res.set("Cache-Control", "public, max-age=30, s-maxage=60");
        res.status(404).send(req.method === "HEAD" ? "" : renderMissingPublicListingHtml());
        return;
      }

      const indexable = isSeoEligiblePublicListing(listing);
      res.set("Content-Type", "text/html; charset=utf-8");
      res.set("Cache-Control", "public, max-age=60, s-maxage=300, stale-while-revalidate=600");
      if (!indexable) res.set("X-Robots-Tag", "noindex, follow");
      if (req.method === "HEAD") {
        res.status(200).send("");
        return;
      }
      res.status(200).send(renderPublicListingHtml(listing, { indexable }));
    } catch (error) {
      logger.error("public_marketplace_seo_failed", {
        path: req.path,
        message: error instanceof Error ? error.message : String(error),
      });
      res.set("Content-Type", "text/html; charset=utf-8");
      res.set("X-Robots-Tag", "noindex, follow");
      res.set("Cache-Control", "no-store");
      res.status(503).send(req.method === "HEAD" ? "" : renderMissingPublicListingHtml());
    }
  },
);
