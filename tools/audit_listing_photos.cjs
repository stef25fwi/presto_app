#!/usr/bin/env node
"use strict";
const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

(async () => {
  const snap = await db.collection("listings").where("status", "==", "active").limit(10).get();
  console.log(`Active listings: ${snap.size}`);
  snap.docs.forEach((d) => {
    const data = d.data();
    const media = data.media || [];
    const imageUrls = data.imageUrls || [];
    const thumbnailUrl = data.thumbnailUrl || "";
    console.log(`\nID: ${d.id}`);
    console.log(`  title: ${data.title}`);
    console.log(`  imageUrls (${imageUrls.length}): ${JSON.stringify(imageUrls.slice(0, 2))}`);
    console.log(`  thumbnailUrl: ${thumbnailUrl ? thumbnailUrl.substring(0, 80) + "..." : "NONE"}`);
    console.log(`  media (${media.length}):`);
    media.forEach((m, i) => {
      console.log(`    [${i}] downloadUrl: ${m.downloadUrl ? m.downloadUrl.substring(0, 80) + "..." : "NONE"}`);
      console.log(`    [${i}] thumbnailUrl: ${m.thumbnailUrl ? m.thumbnailUrl.substring(0, 80) + "..." : "NONE"}`);
      console.log(`    [${i}] storagePath: ${m.storagePath || "NONE"}`);
    });
    console.log(`  mediaProcessingStatus: ${data.mediaProcessingStatus || "NONE"}`);
  });
  process.exit(0);
})();
