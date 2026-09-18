import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import {
  extractPublicProfileId,
  isIndexablePublicProfile,
  normalizePublicProfile,
  publicProfileCanonical,
  renderMissingPublicProfileHtml,
  renderPublicProfileHtml,
  renderPublicProfilesSitemap,
} from "./public_profiles_core";

const PUBLIC_COLLECTION = "public_service_profiles";

interface SeoHeaderResponse {
  set(field: string, value?: string): unknown;
}

function applySeoHeaders(res: SeoHeaderResponse): void {
  res.set("X-Content-Type-Options", "nosniff");
  res.set("Referrer-Policy", "strict-origin-when-cross-origin");
}

export const publicProfilesSeo = onRequest(
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
      if (req.path === "/sitemap-prestataires.xml") {
        const snapshot = await db.collection(PUBLIC_COLLECTION).limit(50_000).get();
        const profiles = snapshot.docs.map((doc) =>
          normalizePublicProfile(doc.id, doc.data()),
        );
        const sitemap = renderPublicProfilesSitemap(profiles);
        res.set("Content-Type", "application/xml; charset=utf-8");
        res.set("Cache-Control", "public, max-age=300, s-maxage=900, stale-while-revalidate=1800");
        res.status(200).send(req.method === "HEAD" ? "" : sitemap);
        return;
      }

      const publicId = extractPublicProfileId(req.path);
      if (!publicId) {
        res.set("Content-Type", "text/html; charset=utf-8");
        res.set("X-Robots-Tag", "noindex, follow");
        res.set("Cache-Control", "no-store");
        res.status(404).send(req.method === "HEAD" ? "" : renderMissingPublicProfileHtml());
        return;
      }

      const canonical = publicProfileCanonical(publicId);
      if (!req.path.endsWith("/")) {
        res.redirect(301, canonical);
        return;
      }

      const snapshot = await db.collection(PUBLIC_COLLECTION).doc(publicId).get();
      const profile = snapshot.exists
        ? normalizePublicProfile(snapshot.id, snapshot.data() || {})
        : null;

      if (!profile || !isIndexablePublicProfile(profile)) {
        res.set("Content-Type", "text/html; charset=utf-8");
        res.set("X-Robots-Tag", "noindex, follow");
        res.set("Cache-Control", "public, max-age=30, s-maxage=60");
        res.status(404).send(req.method === "HEAD" ? "" : renderMissingPublicProfileHtml());
        return;
      }

      res.set("Content-Type", "text/html; charset=utf-8");
      res.set("Cache-Control", "public, max-age=60, s-maxage=300, stale-while-revalidate=600");
      res.status(200).send(req.method === "HEAD" ? "" : renderPublicProfileHtml(profile));
    } catch (error) {
      logger.error("public_profiles_seo_failed", {
        path: req.path,
        message: error instanceof Error ? error.message : String(error),
      });
      res.set("Content-Type", "text/html; charset=utf-8");
      res.set("X-Robots-Tag", "noindex, follow");
      res.set("Cache-Control", "no-store");
      res.status(503).send(req.method === "HEAD" ? "" : renderMissingPublicProfileHtml());
    }
  },
);
