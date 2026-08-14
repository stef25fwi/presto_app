#!/usr/bin/env node

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

import ffmpegPath from "ffmpeg-static";
import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";
import { GoogleAuth } from "google-auth-library";

const projectId = process.env.PROJECT_ID || "presto-app-74abe";
const region = process.env.FUNCTIONS_REGION || "europe-west1";
const apiKey = String(process.env.FIREBASE_API_KEY || "").trim();
const appId = String(process.env.FIREBASE_APP_ID || "").trim();
const smokeUid = `ci-openai-smoke-${Date.now()}`;
const phrase =
  process.env.SMOKE_PHRASE ||
  "Je cherche un peintre à Baie-Mahault pour repeindre une chambre samedi matin.";
const requiredFunctions = [
  "microIaProcessAudioV2",
  "purgeExpiredAiAudio",
  "purgeExpiredAiOperationalData",
  "adminGetAiMetrics",
];
const forbiddenLogKeys = /(?:email|phone|prompt|content|transcript|transcription|audiobase64|imagebase64|base64|authorization|token|secret|password)/i;

if (!apiKey) throw new Error("FIREBASE_API_KEY is required");
if (!appId) throw new Error("FIREBASE_APP_ID is required");
if (!ffmpegPath) throw new Error("ffmpeg-static binary is unavailable");

initializeApp({ credential: applicationDefault(), projectId });
const googleAuth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/cloud-platform"],
});

async function createFirebaseTokens() {
  const customToken = await getAuth().createCustomToken(smokeUid, {
    aiSmokeTest: true,
    admin: true,
  });
  // L'API Authentication applique App Check : le jeton doit être créé avant
  // l'échange et joint à la requête, sinon Identity Toolkit répond 401.
  const appCheck = await getAppCheck().createToken(appId, {
    ttlMillis: 10 * 60 * 1000,
  });
  const authResponse = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "X-Firebase-AppCheck": appCheck.token,
      },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const authPayload = await authResponse.json();
  if (!authResponse.ok || !authPayload.idToken) {
    throw new Error(`Unable to exchange custom token: ${JSON.stringify(authPayload)}`);
  }
  return { idToken: authPayload.idToken, appCheckToken: appCheck.token };
}

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`${command} failed (${result.status}): ${result.stderr || result.stdout}`);
  }
}

async function createSyntheticM4a() {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "ilipresto-ai-smoke-"));
  const wavPath = path.join(directory, "smoke.wav");
  const m4aPath = path.join(directory, "smoke.m4a");
  run("espeak-ng", ["-v", "fr-fr", "-s", "145", "-w", wavPath, phrase]);
  run(ffmpegPath, [
    "-y",
    "-loglevel",
    "error",
    "-i",
    wavPath,
    "-c:a",
    "aac",
    "-b:a",
    "64k",
    m4aPath,
  ]);
  const bytes = await fs.readFile(m4aPath);
  if (!bytes.length) throw new Error("Synthetic smoke audio is empty");
  return { directory, bytes };
}

async function callCallableRaw(name, data, tokens) {
  const response = await fetch(
    `https://${region}-${projectId}.cloudfunctions.net/${name}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${tokens.idToken}`,
        "x-firebase-appcheck": tokens.appCheckToken,
      },
      body: JSON.stringify({ data }),
    },
  );
  const payload = await response.json().catch(() => null);
  return { response, payload };
}

async function callCallable(name, data, tokens) {
  const { response, payload } = await callCallableRaw(name, data, tokens);
  if (!response.ok || payload?.error) {
    throw new Error(`${name} failed http=${response.status}: ${JSON.stringify(payload)}`);
  }
  return payload?.result ?? payload?.data ?? payload;
}

async function forceV2UnavailableThenRecoverWithV1(data, tokens) {
  const missingName = "microIaProcessAudioV2UnavailableSmoke";
  const failed = await callCallableRaw(missingName, data, tokens);
  if (failed.response.ok && !failed.payload?.error) {
    throw new Error("Forced V2-unavailable scenario unexpectedly succeeded");
  }
  const code = String(
    failed.payload?.error?.status ||
      failed.payload?.error?.code ||
      failed.response.status,
  );
  const recovered = await callCallable(
    "microIaProcessAudio",
    { ...data, clientRequestId: `smoke_v1_recovery_${Date.now()}` },
    tokens,
  );
  if (!extractText(recovered)) {
    throw new Error("V1 did not recover after the forced V2 unavailable scenario");
  }
  return { forcedV2Failure: code, recoveredWithV1: true };
}

async function assertFunctionsActive() {
  const client = await googleAuth.getClient();
  const states = {};
  for (const name of requiredFunctions) {
    const url =
      `https://cloudfunctions.googleapis.com/v2/projects/${projectId}` +
      `/locations/${region}/functions/${name}`;
    const response = await client.request({ url });
    const state = String(response.data?.state || "");
    if (state !== "ACTIVE") {
      throw new Error(`${name} is not ACTIVE (state=${state || "unknown"})`);
    }
    states[name] = state;
  }
  return states;
}

async function assertFallbackContract() {
  const source = await fs.readFile(
    path.resolve(process.cwd(), "../lib/features/micro_ia/micro_ia_service.dart"),
    "utf8",
  );
  const required = [
    "fallbackToV1Enabled",
    "_canFallbackToV1",
    "error.code == 'not-found'",
    "functionName: 'microIaProcessAudio'",
    "'clientPipelineSelection': 'v1_fallback'",
  ];
  const missing = required.filter((value) => !source.includes(value));
  if (missing.length) {
    throw new Error(`Flutter fallback contract missing: ${missing.join(", ")}`);
  }
}

function collectSensitiveKeys(value, pathPrefix = "") {
  if (!value || typeof value !== "object") return [];
  const matches = [];
  for (const [key, child] of Object.entries(value)) {
    const fullPath = pathPrefix ? `${pathPrefix}.${key}` : key;
    if (forbiddenLogKeys.test(key)) matches.push(fullPath);
    matches.push(...collectSensitiveKeys(child, fullPath));
  }
  return matches;
}

async function readRecentLogs(sinceIso) {
  const client = await googleAuth.getClient();
  const response = await client.request({
    url: "https://logging.googleapis.com/v2/entries:list",
    method: "POST",
    data: {
      resourceNames: [`projects/${projectId}`],
      filter:
        `timestamp >= \"${sinceIso}\" AND ` +
        '(resource.type="cloud_run_revision" OR resource.type="cloud_function")',
      orderBy: "timestamp desc",
      pageSize: 1000,
    },
  });
  return Array.isArray(response.data?.entries) ? response.data.entries : [];
}

function logPayload(entry) {
  if (entry?.jsonPayload && typeof entry.jsonPayload === "object") {
    return entry.jsonPayload;
  }
  if (typeof entry?.textPayload === "string") {
    try {
      return JSON.parse(entry.textPayload);
    } catch {
      return null;
    }
  }
  return null;
}

async function verifyStructuredLogs(requestId, sinceIso) {
  for (let attempt = 1; attempt <= 10; attempt += 1) {
    const payloads = (await readRecentLogs(sinceIso))
      .map(logPayload)
      .filter((payload) => payload?.requestId === requestId);
    const success = payloads.find(
      (payload) => payload.message === "openai.operation.success",
    );
    if (success) {
      for (const field of ["requestId", "openAiRequestId", "model", "durationMs"]) {
        if (success[field] == null || success[field] === "") {
          throw new Error(`Structured OpenAI log is missing ${field}`);
        }
      }
      const sensitiveKeys = payloads.flatMap((payload) => collectSensitiveKeys(payload));
      if (sensitiveKeys.length) {
        throw new Error(`Sensitive log keys detected: ${sensitiveKeys.join(", ")}`);
      }
      return { entries: payloads.length, openAiRequestId: success.openAiRequestId };
    }
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }
  throw new Error(`No structured OpenAI success log found for requestId=${requestId}`);
}

function extractText(result) {
  return String(
    result?.text ||
      result?.transcript ||
      result?.transcription?.text ||
      result?.transcription ||
      "",
  ).trim();
}

async function main() {
  const sinceIso = new Date(Date.now() - 60_000).toISOString();
  const [tokens, functionStates, syntheticAudio] = await Promise.all([
    createFirebaseTokens(),
    assertFunctionsActive(),
    createSyntheticM4a(),
    assertFallbackContract(),
  ]);
  try {
    const commonData = {
      audioBase64: syntheticAudio.bytes.toString("base64"),
      audioContentType: "audio/mp4",
      languageCode: "fr-FR",
      generateDraft: true,
      draftCity: "Baie-Mahault",
      draftCategory: "Peinture",
    };
    const v2RequestId = `smoke_v2_${Date.now()}`;
    const v2 = await callCallable(
      "microIaProcessAudioV2",
      { ...commonData, clientRequestId: v2RequestId },
      tokens,
    );
    if (!extractText(v2)) throw new Error("V2 smoke returned an empty transcript");
    if (!v2?.pipelineVersion) throw new Error("V2 smoke missing pipelineVersion");

    const forcedFallback = await forceV2UnavailableThenRecoverWithV1(
      commonData,
      tokens,
    );
    const logProof = await verifyStructuredLogs(v2RequestId, sinceIso);
    console.log(
      JSON.stringify(
        {
          ok: true,
          functionStates,
          auth: true,
          appCheck: true,
          v2: {
            modeUsed: v2.modeUsed,
            fallbackUsed: v2.meta?.fallbackUsed === true,
            pipelineVersion: v2.pipelineVersion,
            transcriptLength: extractText(v2).length,
          },
          fallback: forcedFallback,
          logs: logProof,
        },
        null,
        2,
      ),
    );
  } finally {
    await fs.rm(syntheticAudio.directory, { recursive: true, force: true });
    await getAuth().deleteUser(smokeUid).catch(() => undefined);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack || error.message : String(error));
  process.exitCode = 1;
});
