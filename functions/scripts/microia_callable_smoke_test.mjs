import process from "node:process";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const projectId = process.env.PROJECT_ID || "presto-app-74abe";
const region = process.env.FUNCTIONS_REGION || "us-east1";
const idToken = process.env.FIREBASE_ID_TOKEN || "";
const draftHint =
  process.env.DRAFT_HINT ||
  "Peintre pour salon à Pointe-à-Pitre demain, budget 120 euros.";
const draftCity = process.env.DRAFT_CITY || "Pointe-à-Pitre";
const draftCategory = process.env.DRAFT_CATEGORY || "Peinture";
const storagePath = process.env.MICROIA_STORAGE_PATH || "";

const requiredExports = [
  "placesAutocomplete",
  "placesDetails",
  "generateOfferDraft",
  "adminGetUserStats",
  "getUserPresenceStatus",
  "microIaProcessAudio",
  "adminGetMicroIaConfig",
  "adminSetMicroIaConfig",
];

function requireModule(modulePath) {
  const mod = require(modulePath);
  return mod && mod.default ? mod.default : mod;
}

function assertExports(label, mod) {
  const missing = requiredExports.filter((name) => typeof mod[name] === "undefined");
  if (missing.length > 0) {
    throw new Error(`${label} missing exports: ${missing.join(", ")}`);
  }
  console.log(`[ok] ${label} exports: ${requiredExports.join(", ")}`);
}

async function callCallable(name, data) {
  const url = `https://${region}-${projectId}.cloudfunctions.net/${name}`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data }),
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    throw new Error(`${name} http=${response.status} payload=${JSON.stringify(payload)}`);
  }

  if (payload && payload.error) {
    throw new Error(`${name} callable error=${JSON.stringify(payload.error)}`);
  }

  return payload?.result ?? payload?.data ?? payload;
}

async function main() {
  const legacyIndex = requireModule("../index.js");
  const tsIndex = requireModule("../lib/index.js");

  assertExports("legacy index.js", legacyIndex);
  assertExports("compiled lib/index.js", tsIndex);

  if (!idToken) {
    console.log("[skip] No FIREBASE_ID_TOKEN provided, live callable checks skipped.");
    return;
  }

  const draftResult = await callCallable("generateOfferDraft", {
    hint: draftHint,
    city: draftCity,
    category: draftCategory,
    lang: "fr",
  });

  console.log("[ok] generateOfferDraft live call returned keys:", Object.keys(draftResult || {}));

  if (!storagePath) {
    console.log("[skip] No MICROIA_STORAGE_PATH provided, microIaProcessAudio live check skipped.");
    return;
  }

  const microIaResult = await callCallable("microIaProcessAudio", {
    storagePath,
    languageCode: "fr-FR",
    generateDraft: true,
    draftCity,
    draftCategory,
  });

  console.log("[ok] microIaProcessAudio live call returned keys:", Object.keys(microIaResult || {}));
}

main().catch((error) => {
  console.error("[fail] microia callable smoke test", error);
  process.exitCode = 1;
});