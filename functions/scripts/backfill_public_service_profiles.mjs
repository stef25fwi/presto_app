#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

import {
  buildPublicProfileProjection,
  publicProfileIdForUid,
  sourceProfilePublicEligibilityReasons,
} from "../lib/modules/seo/public_profiles_core.js";

function parseArgs(argv) {
  const options = {
    apply: false,
    projectId: process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "",
    limit: 0,
    output: "build/quality/seo-public-profile-activation.json",
  };
  for (const arg of argv.slice(2)) {
    if (arg === "--apply") options.apply = true;
    else if (arg.startsWith("--project=")) options.projectId = arg.slice("--project=".length).trim();
    else if (arg.startsWith("--limit=")) options.limit = Math.max(0, Number(arg.slice("--limit=".length)) || 0);
    else if (arg.startsWith("--output=")) options.output = arg.slice("--output=".length).trim();
  }
  return options;
}

function addReason(summary, reason) {
  summary[reason] = Number(summary[reason] || 0) + 1;
}

const options = parseArgs(process.argv);
if (!options.projectId) {
  throw new Error("Missing --project or GCLOUD_PROJECT");
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId: options.projectId });
}

const db = admin.firestore();
let query = db.collection("pro_profiles")
  .select(
    "seoPublicProfileConsent",
    "siretVerified",
    "establishmentActive",
    "companyName",
    "activity",
    "description",
    "serviceCategories",
    "interventionZone",
    "city",
    "postalCode",
    "website",
  );
if (options.limit > 0) query = query.limit(options.limit);

const snapshot = await query.get();
const reasonCounts = {};
let eligible = 0;
let existingProjection = 0;
let missingProjection = 0;
let applied = 0;

let batch = db.batch();
let batchSize = 0;
const MAX_BATCH = 400;

async function commitBatch() {
  if (!options.apply || batchSize === 0) return;
  await batch.commit();
  applied += batchSize;
  batch = db.batch();
  batchSize = 0;
}

for (const doc of snapshot.docs) {
  const data = doc.data() || {};
  const reasons = sourceProfilePublicEligibilityReasons(data);
  if (reasons.length > 0) {
    for (const reason of reasons) addReason(reasonCounts, reason);
    continue;
  }

  eligible += 1;
  const publicId = publicProfileIdForUid(doc.id);
  const target = db.collection("public_service_profiles").doc(publicId);
  const current = await target.get();
  if (current.exists) existingProjection += 1;
  else missingProjection += 1;

  if (!options.apply) continue;

  const projection = buildPublicProfileProjection(doc.id, data);
  const publishedAt = current.exists && current.data()?.publishedAt
    ? current.data().publishedAt
    : FieldValue.serverTimestamp();

  batch.set(target, {
    ...projection,
    publishedAt,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: false });
  batchSize += 1;
  if (batchSize >= MAX_BATCH) await commitBatch();
}

await commitBatch();

const report = {
  generatedAt: new Date().toISOString(),
  projectId: options.projectId,
  mode: options.apply ? "apply" : "dry-run",
  scannedSourceProfiles: snapshot.size,
  eligibleConsentedProfiles: eligible,
  existingPublicProjections: existingProjection,
  missingPublicProjections: missingProjection,
  appliedPublicProjections: applied,
  ineligibleReasonCounts: reasonCounts,
  privacy: {
    containsProfileIds: false,
    containsContactData: false,
    containsSourceContent: false,
  },
};

fs.mkdirSync(path.dirname(options.output), { recursive: true });
fs.writeFileSync(options.output, `${JSON.stringify(report, null, 2)}\n`, "utf8");

console.log(JSON.stringify(report, null, 2));
