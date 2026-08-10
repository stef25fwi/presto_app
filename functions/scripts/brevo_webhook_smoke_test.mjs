#!/usr/bin/env node

function usage() {
  console.log("Usage: node scripts/brevo_webhook_smoke_test.mjs --url <webhook_url> --secret <brevo_webhook_secret>");
  console.log("or set WEBHOOK_URL and BREVO_WEBHOOK_SECRET env vars.");
}

function readArg(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return undefined;
  return process.argv[idx + 1];
}

async function postEvent(url, token, payload) {
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  });

  return {
    ok: res.ok,
    status: res.status,
    body: await res.text().catch(() => ""),
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
      id: 26224,
      "message-id": `smoke-delivered-${nowSec}`,
      ts_event: nowSec,
      ts_epoch: Date.now(),
    },
    {
      event: "opened",
      email: recipient,
      id: 26224,
      "message-id": `smoke-opened-${nowSec}`,
      ts_event: nowSec,
    },
    {
      event: "click",
      email: recipient,
      id: 26224,
      "message-id": `smoke-clicked-${nowSec}`,
      ts_event: nowSec,
    },
    {
      event: "soft_bounce",
      email: recipient,
      id: 26224,
      "message-id": `smoke-soft-bounce-${nowSec}`,
      ts_event: nowSec,
      reason: "temporary smoke-test failure",
    },
  ];

  const runs = [];
  for (const payload of payloads) {
    runs.push(await postEvent(url, secret, payload));
  }

  let failed = 0;
  console.log("Brevo webhook smoke test results:");
  for (const run of runs) {
    const marker = run.ok ? "OK" : "KO";
    if (!run.ok) failed += 1;
    console.log(`[${marker}] event=${run.event} auth=bearer status=${run.status}`);
    if (!run.ok) console.log(`  body=${run.body}`);
  }

  // Authentication must fail closed.
  const invalid = await postEvent(url, `${secret}-invalid`, payloads[0]);
  if (invalid.status !== 401) {
    failed += 1;
    console.error(`[KO] invalid bearer token expected=401 actual=${invalid.status} body=${invalid.body}`);
  } else {
    console.log("[OK] invalid bearer token rejected with 401");
  }

  const methodProbe = await fetch(url, { method: "GET" });
  if (methodProbe.status !== 405) {
    failed += 1;
    console.error(`[KO] GET expected=405 actual=${methodProbe.status}`);
  } else {
    console.log("[OK] non-POST method rejected with 405");
  }

  if (failed > 0) {
    console.error(`Smoke test failed: ${failed} check(s) failed.`);
    process.exit(2);
  }

  console.log(`Smoke test passed: ${runs.length} valid events accepted and security probes rejected.`);
}

main().catch((err) => {
  console.error("Smoke test crashed:", err);
  process.exit(99);
});
