#!/usr/bin/env node
"use strict";

/**
 * Audit complet du pipeline photo des annonces :
 * 1. Vérifie les documents Firestore (listings + offers) : champs media, imageUrls, thumbnailUrl
 * 2. Vérifie que les fichiers Storage existent réellement
 * 3. Vérifie que les downloadUrl HTTP répondent (HEAD request)
 *
 * Usage: node tools/audit_photo_pipeline.cjs [--sample=N] [--collection=listings|offers|both]
 */

const admin = require("firebase-admin");
const https = require("https");
const http = require("http");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const bucket = admin.storage().bucket();

// ── CLI args ──
const args = process.argv.slice(2);
const sampleSize = parseInt((args.find((a) => a.startsWith("--sample=")) || "--sample=10").split("=")[1], 10);
const collectionArg = (args.find((a) => a.startsWith("--collection=")) || "--collection=both").split("=")[1];

// ── Helpers ──
function headCheck(url, timeoutMs = 8000) {
  return new Promise((resolve) => {
    if (!url || typeof url !== "string") return resolve({ ok: false, status: 0, error: "empty_url" });
    const trimmed = url.trim();
    if (!trimmed.startsWith("http://") && !trimmed.startsWith("https://")) {
      return resolve({ ok: false, status: 0, error: `not_http: ${trimmed.substring(0, 60)}` });
    }
    const lib = trimmed.startsWith("https") ? https : http;
    const req = lib.request(trimmed, { method: "HEAD", timeout: timeoutMs }, (res) => {
      resolve({ ok: res.statusCode >= 200 && res.statusCode < 400, status: res.statusCode });
    });
    req.on("error", (err) => resolve({ ok: false, status: 0, error: err.code || err.message }));
    req.on("timeout", () => { req.destroy(); resolve({ ok: false, status: 0, error: "TIMEOUT" }); });
    req.end();
  });
}

async function storageExists(storagePath) {
  if (!storagePath || typeof storagePath !== "string") return { exists: false, error: "empty_path" };
  try {
    const [exists] = await bucket.file(storagePath.trim()).exists();
    return { exists };
  } catch (err) {
    return { exists: false, error: err.code || err.message };
  }
}

function extractUrls(doc) {
  const data = doc.data();
  const urls = new Set();
  const storPaths = new Set();

  // media array
  const media = data.media || [];
  for (const m of media) {
    if (m.downloadUrl) urls.add(m.downloadUrl);
    if (m.thumbnailUrl) urls.add(m.thumbnailUrl);
    if (m.storagePath) storPaths.add(m.storagePath);
  }

  // imageUrls array (can be strings or maps)
  const imageUrls = data.imageUrls || [];
  for (const entry of imageUrls) {
    if (typeof entry === "string") {
      urls.add(entry);
    } else if (entry && typeof entry === "object") {
      for (const key of ["downloadUrl", "thumbnailUrl", "imageUrl", "url", "src"]) {
        if (entry[key]) urls.add(entry[key]);
      }
      if (entry.storagePath) storPaths.add(entry.storagePath);
    }
  }

  // singular fields
  if (data.imageUrl) urls.add(data.imageUrl);
  if (data.thumbnailUrl) urls.add(data.thumbnailUrl);

  return { urls: [...urls], storagePaths: [...storPaths], media, imageUrls, data };
}

async function auditCollection(collectionName) {
  console.log(`\n${"=".repeat(70)}`);
  console.log(`COLLECTION: ${collectionName} (sample=${sampleSize})`);
  console.log("=".repeat(70));

  // Try to get active/published docs first, fallback to all
  let snap;
  try {
    snap = await db.collection(collectionName)
      .where("status", "in", ["active", "published"])
      .limit(sampleSize)
      .get();
  } catch {
    snap = await db.collection(collectionName).limit(sampleSize).get();
  }

  if (snap.empty) {
    console.log(`  ⚠️  Collection vide ou inexistante`);
    return { total: 0, withMedia: 0, withoutMedia: 0, brokenUrls: 0, missingStorage: 0, issues: [] };
  }

  console.log(`  Documents trouvés: ${snap.size}\n`);

  const stats = { total: snap.size, withMedia: 0, withoutMedia: 0, brokenUrls: 0, missingStorage: 0, issues: [] };

  for (const doc of snap.docs) {
    const { urls, storagePaths, media, imageUrls, data } = extractUrls(doc);
    const hasAnyPhoto = urls.length > 0 || storagePaths.length > 0;
    if (hasAnyPhoto) stats.withMedia++; else stats.withoutMedia++;

    console.log(`─── ${doc.id} ───`);
    console.log(`  title: ${(data.title || "").substring(0, 60)}`);
    console.log(`  status: ${data.status || "NONE"} | visibility: ${data.visibility || "NONE"}`);
    console.log(`  media[]: ${media.length} entries`);
    console.log(`  imageUrls[]: ${imageUrls.length} entries (type: ${imageUrls.length > 0 ? typeof imageUrls[0] : "n/a"})`);
    console.log(`  imageUrl: ${data.imageUrl ? "SET" : "NONE"} | thumbnailUrl: ${data.thumbnailUrl ? "SET" : "NONE"}`);

    if (!hasAnyPhoto) {
      console.log(`  ⚠️  AUCUNE PHOTO\n`);
      stats.issues.push({ id: doc.id, issue: "NO_PHOTOS" });
      continue;
    }

    // Check URLs via HEAD
    for (const url of urls) {
      const trimmed = (url || "").trim();
      if (!trimmed) continue;
      if (trimmed.startsWith("gs://")) {
        // gs:// path - check storage directly
        const gsPath = trimmed.replace(/^gs:\/\/[^/]+\//, "");
        const result = await storageExists(gsPath);
        if (!result.exists) {
          console.log(`  ❌ STORAGE gs:// miss: ${trimmed.substring(0, 80)}`);
          stats.missingStorage++;
          stats.issues.push({ id: doc.id, issue: "GS_MISSING", path: trimmed });
        } else {
          console.log(`  ✅ STORAGE gs://: ${trimmed.substring(0, 80)}`);
        }
      } else if (trimmed.startsWith("http")) {
        const result = await headCheck(trimmed);
        if (result.ok) {
          console.log(`  ✅ URL OK (${result.status}): ${trimmed.substring(0, 80)}...`);
        } else {
          console.log(`  ❌ URL BROKEN (${result.status || result.error}): ${trimmed.substring(0, 80)}...`);
          stats.brokenUrls++;
          stats.issues.push({ id: doc.id, issue: "URL_BROKEN", status: result.status, error: result.error, url: trimmed.substring(0, 120) });
        }
      } else {
        // Probably a raw storage path
        const sResult = await storageExists(trimmed);
        if (sResult.exists) {
          console.log(`  ✅ STORAGE PATH: ${trimmed.substring(0, 80)}`);
        } else {
          console.log(`  ❌ STORAGE PATH MISSING: ${trimmed.substring(0, 80)}`);
          stats.missingStorage++;
          stats.issues.push({ id: doc.id, issue: "STORAGE_MISSING", path: trimmed });
        }
      }
    }

    // Check storage paths from media[].storagePath
    for (const sp of storagePaths) {
      if (!sp || urls.some((u) => u === sp)) continue; // already checked  
      const result = await storageExists(sp);
      if (result.exists) {
        console.log(`  ✅ storagePath: ${sp}`);
      } else {
        console.log(`  ❌ storagePath MISSING: ${sp}`);
        stats.missingStorage++;
        stats.issues.push({ id: doc.id, issue: "STORAGE_PATH_MISSING", path: sp });
      }
    }
    console.log();
  }

  return stats;
}

// ── Main ──
(async () => {
  console.log("🔍 Audit pipeline photo des annonces");
  console.log(`   Date: ${new Date().toISOString()}`);
  console.log(`   Sample: ${sampleSize} | Collection: ${collectionArg}`);

  const results = {};

  if (collectionArg === "listings" || collectionArg === "both") {
    results.listings = await auditCollection("listings");
  }
  if (collectionArg === "offers" || collectionArg === "both") {
    results.offers = await auditCollection("offers");
  }

  // ── Summary ──
  console.log(`\n${"=".repeat(70)}`);
  console.log("RÉSUMÉ DE L'AUDIT");
  console.log("=".repeat(70));

  for (const [name, s] of Object.entries(results)) {
    console.log(`\n  ${name.toUpperCase()}:`);
    console.log(`    Total: ${s.total}`);
    console.log(`    Avec média: ${s.withMedia}`);
    console.log(`    Sans média: ${s.withoutMedia}`);
    console.log(`    URLs cassées: ${s.brokenUrls}`);
    console.log(`    Storage manquant: ${s.missingStorage}`);
    if (s.issues.length > 0) {
      console.log(`    ⚠️  Problèmes (${s.issues.length}):`);
      for (const issue of s.issues) {
        console.log(`      - [${issue.id.substring(0, 20)}] ${issue.issue} ${issue.error || issue.path || issue.url || ""}`);
      }
    } else {
      console.log(`    ✅ Aucun problème détecté`);
    }
  }

  // Check Storage buckets overview
  console.log(`\n${"─".repeat(70)}`);
  console.log("VÉRIFICATION STORAGE BUCKETS:");
  for (const prefix of ["offers/", "offers_raw/"]) {
    try {
      const [files] = await bucket.getFiles({ prefix, maxResults: 5 });
      console.log(`  ${prefix}: ${files.length}${files.length >= 5 ? "+" : ""} fichiers`);
      files.slice(0, 3).forEach((f) => {
        console.log(`    - ${f.name} (${f.metadata.contentType || "?"}, ${(f.metadata.size / 1024).toFixed(1)}KB)`);
      });
    } catch (err) {
      console.log(`  ${prefix}: ERROR - ${err.message}`);
    }
  }

  console.log("\n✅ Audit terminé.");
  process.exit(0);
})();
