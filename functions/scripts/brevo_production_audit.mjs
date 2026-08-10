#!/usr/bin/env node
import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

function readArg(name, fallback) {
  const direct = process.argv.find((arg) => arg.startsWith(`${name}=`));
  if (direct) return direct.slice(name.length + 1);
  const idx = process.argv.indexOf(name);
  if (idx >= 0 && process.argv[idx + 1] && !process.argv[idx + 1].startsWith("--")) {
    return process.argv[idx + 1];
  }
  return fallback;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function parseSenderEmail(value) {
  const raw = String(value || "").trim();
  const match = raw.match(/<([^>]+)>/);
  return String(match?.[1] || raw).trim().toLowerCase();
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function brevoRequest(path, apiKey, options = {}) {
  const response = await fetch(`https://api.brevo.com/v3${path}`, {
    ...options,
    headers: {
      accept: "application/json",
      "api-key": apiKey,
      ...(options.body ? { "content-type": "application/json" } : {}),
      ...(options.headers || {}),
    },
  });

  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text.slice(0, 500) };
  }

  if (!response.ok) {
    const err = new Error(`Brevo ${options.method || "GET"} ${path} -> HTTP ${response.status}`);
    err.status = response.status;
    err.body = body;
    throw err;
  }
  return body;
}

function check(name, ok, details = {}) {
  return { name, ok: Boolean(ok), details };
}

async function waitForDeliveryLog(messageId, timeoutMs) {
  if (getApps().length === 0) initializeApp();
  const db = getFirestore();
  const deadline = Date.now() + timeoutMs;
  const terminalFailures = new Set(["bounced", "complained", "dropped", "failed"]);
  let observed = [];

  while (Date.now() < deadline) {
    const snap = await db
      .collection("email_logs")
      .where("provider_message_id", "==", messageId)
      .limit(20)
      .get();

    observed = snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }));
    const statuses = observed.map((item) => String(item.status || ""));
    if (statuses.includes("delivered")) return { delivered: true, statuses, observed };
    if (statuses.some((status) => terminalFailures.has(status))) {
      return { delivered: false, statuses, observed, terminalFailure: true };
    }
    await sleep(5000);
  }

  return {
    delivered: false,
    statuses: observed.map((item) => String(item.status || "")),
    observed,
    timedOut: true,
  };
}

async function main() {
  const apiKey = String(process.env.BREVO_API_KEY || "").trim();
  const webhookSecret = String(process.env.BREVO_WEBHOOK_SECRET || "").trim();
  const domain = readArg("--domain", process.env.BREVO_SENDER_DOMAIN || "ilipresto.fr");
  const sender = parseSenderEmail(readArg("--sender", process.env.EMAIL_FROM || "noreply@ilipresto.fr"));
  const replyTo = readArg("--reply-to", process.env.EMAIL_REPLY_TO || "contact@ilipresto.fr");
  const webhookUrl = readArg(
    "--webhook-url",
    process.env.WEBHOOK_URL || "https://europe-west1-presto-app-74abe.cloudfunctions.net/handleEmailProviderWebhook",
  );
  const canary = readArg("--canary", process.env.BREVO_CANARY_RECIPIENT || "contact@ilipresto.fr");
  const output = readArg("--output", "quality/brevo-production-certification.json");
  const timeoutMs = Number(readArg("--timeout-ms", process.env.BREVO_E2E_TIMEOUT_MS || "180000"));
  const runE2E = hasFlag("--e2e");

  if (!apiKey) throw new Error("BREVO_API_KEY is required");
  if (!webhookSecret) throw new Error("BREVO_WEBHOOK_SECRET is required");

  const requiredEvents = new Set([
    "sent", "delivered", "hardBounce", "softBounce", "blocked", "spam",
    "invalid", "deferred", "click", "opened", "uniqueOpened", "unsubscribed",
  ]);
  const checks = [];

  const domainConfig = await brevoRequest(`/senders/domains/${encodeURIComponent(domain)}`, apiKey);
  const dnsRecords = domainConfig.dns_records || {};
  const dnsStatuses = Object.fromEntries(
    Object.entries(dnsRecords).map(([key, value]) => [key, Boolean(value?.status)]),
  );
  checks.push(check("domain.verified", domainConfig.verified === true, { domain }));
  checks.push(check("domain.authenticated", domainConfig.authenticated === true, { domain }));
  checks.push(check(
    "domain.dns_records",
    Object.keys(dnsStatuses).length >= 2 && Object.values(dnsStatuses).every(Boolean),
    { dnsStatuses },
  ));
  checks.push(check(
    "domain.dmarc",
    Boolean(dnsRecords.dmarc_record?.status),
    { present: Boolean(dnsRecords.dmarc_record), status: Boolean(dnsRecords.dmarc_record?.status) },
  ));

  const senders = await brevoRequest(`/senders?domain=${encodeURIComponent(domain)}`, apiKey);
  const senderEntry = (senders.senders || []).find(
    (item) => String(item.email || "").trim().toLowerCase() === sender,
  );
  checks.push(check("sender.exists", Boolean(senderEntry), { sender }));
  checks.push(check("sender.active", senderEntry?.active === true, { sender }));

  const webhooks = await brevoRequest("/webhooks?type=transactional", apiKey);
  const hook = (webhooks.webhooks || []).find(
    (item) => item.url === webhookUrl && item.type === "transactional",
  );
  const actualEvents = new Set(hook?.events || []);
  const missingEvents = [...requiredEvents].filter((event) => !actualEvents.has(event));
  checks.push(check("webhook.exists", Boolean(hook), { webhookUrl }));
  checks.push(check("webhook.auth_bearer", String(hook?.auth?.type || "").toLowerCase() === "bearer", {
    webhookId: hook?.id || null,
  }));
  checks.push(check("webhook.events", missingEvents.length === 0, {
    webhookId: hook?.id || null,
    missingEvents,
    eventCount: actualEvents.size,
  }));

  let e2e = null;
  if (runE2E) {
    if (!canary || !String(canary).includes("@")) throw new Error("A valid --canary recipient is required for --e2e");
    const certificationId = randomUUID();
    const sendResponse = await brevoRequest("/smtp/email", apiKey, {
      method: "POST",
      body: JSON.stringify({
        sender: { email: sender, name: "iliprestō" },
        to: [{ email: canary }],
        replyTo: { email: replyTo },
        subject: `iliprestō — certification email ${certificationId.slice(0, 8)}`,
        textContent: `Certification technique Brevo iliprestō. ID: ${certificationId}`,
        htmlContent: `<p>Certification technique Brevo iliprestō.</p><p>ID: <strong>${certificationId}</strong></p>`,
        tags: ["production-certification", "brevo"],
        headers: { "Idempotency-Key": certificationId },
      }),
    });

    const messageId = String(sendResponse.messageId || "");
    checks.push(check("e2e.provider_accepted", Boolean(messageId), { messageId: messageId || null, canary }));

    if (messageId) {
      const delivery = await waitForDeliveryLog(messageId, timeoutMs);
      e2e = {
        certificationId,
        messageId,
        canary,
        statuses: delivery.statuses,
        timedOut: Boolean(delivery.timedOut),
        terminalFailure: Boolean(delivery.terminalFailure),
      };
      checks.push(check("e2e.webhook_delivery", delivery.delivered === true, e2e));
    }
  }

  const failed = checks.filter((item) => !item.ok);
  const report = {
    generatedAt: new Date().toISOString(),
    provider: "brevo",
    domain,
    sender,
    replyTo,
    webhookUrl,
    e2eRequested: runE2E,
    certified: failed.length === 0,
    checks,
    failedChecks: failed.map((item) => item.name),
    e2e,
  };

  await mkdir(dirname(output), { recursive: true });
  await writeFile(output, `${JSON.stringify(report, null, 2)}\n`, "utf8");

  for (const item of checks) {
    console.log(`${item.ok ? "PASS" : "FAIL"} ${item.name}`);
  }
  console.log(`Brevo production certification: ${report.certified ? "PASS" : "FAIL"}`);
  console.log(`Report: ${output}`);

  if (!report.certified) process.exit(2);
}

main().catch((error) => {
  console.error("Brevo production audit failed:", error?.message || String(error));
  if (error?.body) console.error(JSON.stringify(error.body));
  process.exit(1);
});
