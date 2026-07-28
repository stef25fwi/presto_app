import process from "node:process";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const projectId = process.env.PROJECT_ID || "presto-app-74abe";
const region = process.env.FUNCTIONS_REGION || "europe-west1";
const idToken = process.env.FIREBASE_ID_TOKEN || "";
const appCheckToken = process.env.FIREBASE_APP_CHECK_TOKEN || "";
const requireAppCheck = String(process.env.REQUIRE_APP_CHECK || "true").toLowerCase() !== "false";
const useV2 = String(process.env.MICROIA_USE_V2 || "false").toLowerCase() === "true";
const draftHint =
  process.env.DRAFT_HINT ||
  "Peintre pour salon à Pointe-à-Pitre demain, budget 120 euros.";
const draftCity = process.env.DRAFT_CITY || "Pointe-à-Pitre";
const draftCategory = process.env.DRAFT_CATEGORY || "Peinture";
const storagePath = process.env.MICROIA_STORAGE_PATH || "";

const requiredLegacyExports = [
  "placesAutocomplete",
  "placesDetails",
  "generateOfferDraft",
  "adminGetUserStats",
  "getUserPresenceStatus",
  "microIaProcessAudio",
  "adminGetMicroIaConfig",
  "adminSetMicroIaConfig",
];

const requiredTypescriptExports = [
  ...requiredLegacyExports,
  "microIaProcessAudioV2",
  "adminGetAiMetrics",
  "purgeExpiredAiAudio",
  "purgeExpiredAiOperationalData",
];

function requireModule(modulePath) {
  const mod = require(modulePath);
  return mod && mod.default ? mod.default : mod;
}

function assertExports(label, mod, requiredExports) {
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
      ...(appCheckToken ? { "X-Firebase-AppCheck": appCheckToken } : {}),
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

  assertExports("legacy index.js", legacyIndex, requiredLegacyExports);
  assertExports("compiled lib/index.js", tsIndex, requiredTypescriptExports);

  if (!idToken) {
    console.log("[skip] No FIREBASE_ID_TOKEN provided, live callable checks skipped.");
    return;
  }
  if (requireAppCheck && !appCheckToken) {
    console.log("[skip] No FIREBASE_APP_CHECK_TOKEN provided, live callable checks skipped because production callables require App Check.");
    return;
  }

  const draftResult = await callCallable("generateOfferDraft", {
    hint: draftHint,
    city: draftCity,
    category: draftCategory,
    lang: "fr",
    clientRequestId: `smoke_draft_${Date.now()}`,
  });
  console.log("[ok] generateOfferDraft live call returned keys:", Object.keys(draftResult || {}));

  if (!storagePath) {
    console.log("[skip] No MICROIA_STORAGE_PATH provided, Micro IA live check skipped.");
    return;
  }

  const functionName = useV2 ? "microIaProcessAudioV2" : "microIaProcessAudio";
  const microIaResult = await callCallable(functionName, {
    storagePath,
    languageCode: "fr-FR",
    generateDraft: true,
    draftCity,
    draftCategory,
    clientRequestId: `smoke_audio_${Date.now()}`,
  });
  console.log(`[ok] ${functionName} live call returned keys:`, Object.keys(microIaResult || {}));
}

main().catch((error) => {
  console.error("[fail] microia callable smoke test", error);
  process.exitCode = 1;
});
