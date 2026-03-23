#!/usr/bin/env node
import { createHmac } from "node:crypto";

function usage() {
  console.log("Usage: node scripts/brevo_webhook_smoke_test.mjs --url <webhook_url> --secret <brevo_webhook_secret>");
  console.log("or set WEBHOOK_URL and BREVO_WEBHOOK_SECRET env vars.");
}

function readArg(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return undefined;
  return process.argv[idx + 1];
}

function signPayload(rawBody, secret, mode) {
  const hex = createHmac("sha256", secret).update(rawBody).digest("hex");
  if (mode === "prefixed") return `sha256=${hex}`;
  return hex;
}

async function postEvent(url, secret, payload, signatureMode) {
  const rawBody = JSON.stringify(payload);
  const signature = signPayload(rawBody, secret, signatureMode);

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-mailin-signature": signature,
    },
    body: rawBody,
  });

  let body = "";
  try {
    body = await res.text();
  } catch {
    body = "";
  }

  return {
    ok: res.ok,
    status: res.status,
    body,
    signatureMode,
    event: payload.event,
  };
}

async function main() {
  const url = readArg("--url") || process.env.WEBHOOK_URL;
  const secret = readArg("--secret") || process.env.BREVO_WEBHOOK_SECRET;

  if (!url || !secret) {
    usage();
    process.exit(1);
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const recipient = `smoke-test-${nowSec}@example.invalid`;

  // Only non-suppressing events to avoid polluting suppression lists.
  const payloads = [
    {
      event: "delivered",
      email: recipient,
      "message-id": `smoke-delivered-${nowSec}`,
      timestamp: String(nowSec),
    },
    {
      event: "opened",
      email: recipient,
      "message-id": `smoke-opened-${nowSec}`,
      timestamp: String(nowSec),
    },
    {
      event: "clicked",
      email: recipient,
      "message-id": `smoke-clicked-${nowSec}`,
      timestamp: String(nowSec),
    },
  ];

  const runs = [];
  for (const payload of payloads) {
    runs.push(await postEvent(url, secret, payload, "hex"));
    runs.push(await postEvent(url, secret, payload, "prefixed"));
  }

  let failed = 0;
  console.log("Brevo webhook smoke test results:");
  for (const run of runs) {
    const marker = run.ok ? "OK" : "KO";
    if (!run.ok) failed += 1;
    console.log(`[${marker}] event=${run.event} sig=${run.signatureMode} status=${run.status}`);
    if (!run.ok) {
      console.log(`  body=${run.body}`);
    }
  }

  if (failed > 0) {
    console.error(`Smoke test failed: ${failed}/${runs.length} requests failed.`);
    process.exit(2);
  }

  console.log(`Smoke test passed: ${runs.length}/${runs.length} requests accepted.`);
}

main().catch((err) => {
  console.error("Smoke test crashed:", err);
  process.exit(99);
});
