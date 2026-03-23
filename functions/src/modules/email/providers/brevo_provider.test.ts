import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import test from "node:test";
import { BrevoProvider } from "./brevo_provider";
import { createEmailProvider } from "./provider_factory";

function withEnv(vars: Record<string, string | undefined>, run: () => void): void {
  const previous = new Map<string, string | undefined>();

  for (const [key, value] of Object.entries(vars)) {
    previous.set(key, process.env[key]);
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }

  try {
    run();
  } finally {
    for (const [key, value] of previous.entries()) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  }
}

test("BrevoProvider verifies x-mailin-signature", () => {
  const secret = "brevo_webhook_secret";
  const rawBody = JSON.stringify({ event: "delivered", email: "user@example.com" });
  const signature = createHmac("sha256", secret).update(rawBody).digest("hex");
  const provider = new BrevoProvider("api_key", secret);

  assert.equal(provider.verifyWebhookSignature({ "x-mailin-signature": signature }, rawBody), true);
  assert.equal(provider.verifyWebhookSignature({ "x-mailin-signature": "bad" }, rawBody), false);
});

test("BrevoProvider verifies sha256= prefixed signature", () => {
  const secret = "brevo_webhook_secret";
  const rawBody = JSON.stringify({ event: "opened", email: "user@example.com" });
  const signature = createHmac("sha256", secret).update(rawBody).digest("hex");
  const provider = new BrevoProvider("api_key", secret);

  assert.equal(provider.verifyWebhookSignature({ "x-mailin-signature": `sha256=${signature}` }, rawBody), true);
});

test("BrevoProvider parses Brevo webhook events", () => {
  const provider = new BrevoProvider("api_key", "webhook_secret");
  const [event] = provider.parseWebhook({
    event: "hard_bounce",
    email: "user@example.com",
    "message-id": "brevo-message-1",
  });

  assert.ok(event);
  assert.equal(event.type, "bounced");
  assert.equal(event.recipient, "user@example.com");
  assert.equal(event.providerMessageId, "brevo-message-1");
});

test("BrevoProvider parses event timestamp from payload", () => {
  const provider = new BrevoProvider("api_key", "webhook_secret");
  const [event] = provider.parseWebhook({
    event: "delivered",
    email: "user@example.com",
    "message-id": "brevo-message-2",
    timestamp: "1700000000",
  });

  assert.ok(event);
  assert.equal(event.occurredAt, 1700000000 * 1000);
});

test("provider factory auto-selects Brevo when BREVO_API_KEY is present", () => {
  withEnv(
    {
      EMAIL_PROVIDER_NAME: undefined,
      BREVO_API_KEY: "brevo_api_key",
      BREVO_WEBHOOK_SECRET: "brevo_webhook_secret",
      EMAIL_PROVIDER_API_KEY: undefined,
      EMAIL_PROVIDER_WEBHOOK_SECRET: undefined,
    },
    () => {
      const provider = createEmailProvider();
      assert.equal(provider.name(), "brevo");
    },
  );
});

test("provider factory honors explicit resend selection", () => {
  withEnv(
    {
      EMAIL_PROVIDER_NAME: "resend",
      BREVO_API_KEY: "brevo_api_key",
      BREVO_WEBHOOK_SECRET: "brevo_webhook_secret",
      EMAIL_PROVIDER_API_KEY: "resend_api_key",
      EMAIL_PROVIDER_WEBHOOK_SECRET: "resend_webhook_secret",
    },
    () => {
      const provider = createEmailProvider();
      assert.equal(provider.name(), "resend");
    },
  );
});

test("provider factory rejects unsupported explicit provider", () => {
  withEnv(
    {
      EMAIL_PROVIDER_NAME: "mailjet",
      BREVO_API_KEY: "brevo_api_key",
      BREVO_WEBHOOK_SECRET: "brevo_webhook_secret",
      EMAIL_PROVIDER_API_KEY: "resend_api_key",
      EMAIL_PROVIDER_WEBHOOK_SECRET: "resend_webhook_secret",
    },
    () => {
      assert.throws(() => createEmailProvider(), /Unsupported EMAIL_PROVIDER_NAME/);
    },
  );
});