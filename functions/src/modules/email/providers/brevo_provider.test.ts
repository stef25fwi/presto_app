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

test("BrevoProvider verifies official Bearer webhook authentication", () => {
  const secret = "brevo_webhook_secret";
  const provider = new BrevoProvider("api_key", secret);

  assert.equal(
    provider.verifyWebhookSignature({ authorization: `Bearer ${secret}` }, "{}"),
    true,
  );
  assert.equal(
    provider.verifyWebhookSignature({ authorization: "Bearer invalid" }, "{}"),
    false,
  );
});

test("BrevoProvider authentifie malgré un saut de ligne final dans le secret stocké", () => {
  const secret = "brevo_webhook_secret";
  // Secret Manager restitue la valeur telle qu'elle a été écrite : un `echo`
  // sans `-n` ou un collage en console y laisse un saut de ligne, que
  // `process.env` conserve alors que l'appelant envoie le jeton nettoyé.
  const provider = new BrevoProvider("api_key\n", `${secret}\n`);

  assert.equal(
    provider.verifyWebhookSignature({ authorization: `Bearer ${secret}` }, "{}"),
    true,
  );
  assert.equal(
    provider.verifyWebhookSignature({ "x-ilipresto-webhook-secret": secret }, "{}"),
    true,
  );
  assert.equal(
    provider.verifyWebhookSignature({ authorization: "Bearer invalid" }, "{}"),
    false,
  );
});

test("BrevoProvider accepts configured custom webhook secret header", () => {
  const secret = "brevo_webhook_secret";
  const provider = new BrevoProvider("api_key", secret);

  assert.equal(
    provider.verifyWebhookSignature({ "x-ilipresto-webhook-secret": secret }, "{}"),
    true,
  );
});

test("BrevoProvider keeps legacy x-mailin-signature compatibility", () => {
  const secret = "brevo_webhook_secret";
  const rawBody = JSON.stringify({ event: "delivered", email: "user@example.com" });
  const signature = createHmac("sha256", secret).update(rawBody).digest("hex");
  const provider = new BrevoProvider("api_key", secret);

  assert.equal(provider.verifyWebhookSignature({ "x-mailin-signature": signature }, rawBody), true);
  assert.equal(provider.verifyWebhookSignature({ "x-mailin-signature": "bad" }, rawBody), false);
});

test("BrevoProvider distinguishes hard and soft bounces", () => {
  const provider = new BrevoProvider("api_key", "webhook_secret");
  const [hard] = provider.parseWebhook({
    event: "hard_bounce",
    email: "USER@example.com",
    "message-id": "brevo-message-hard",
    ts_event: 1700000000,
  });
  const [soft] = provider.parseWebhook({
    event: "soft_bounce",
    email: "user@example.com",
    "message-id": "brevo-message-soft",
    ts_event: 1700000001,
  });

  assert.ok(hard);
  assert.ok(soft);
  assert.equal(hard.type, "bounced");
  assert.equal(hard.bounceKind, "hard");
  assert.equal(hard.recipient, "user@example.com");
  assert.equal(soft.type, "bounced");
  assert.equal(soft.bounceKind, "soft");
});

test("BrevoProvider uses Brevo event timestamp fields", () => {
  const provider = new BrevoProvider("api_key", "webhook_secret");
  const [event] = provider.parseWebhook({
    event: "delivered",
    email: "user@example.com",
    "message-id": "brevo-message-2",
    ts_epoch: 1700000000123,
    ts_event: 1700000000,
  });

  assert.ok(event);
  assert.equal(event.occurredAt, 1700000000123);
});

test("BrevoProvider does not treat webhook id as provider event id", () => {
  const provider = new BrevoProvider("api_key", "webhook_secret");
  const [eventA] = provider.parseWebhook({
    id: 26224,
    event: "delivered",
    email: "a@example.com",
    "message-id": "message-a",
    ts_event: 1700000000,
  });
  const [eventB] = provider.parseWebhook({
    id: 26224,
    event: "delivered",
    email: "b@example.com",
    "message-id": "message-b",
    ts_event: 1700000001,
  });

  assert.ok(eventA);
  assert.ok(eventB);
  assert.notEqual(eventA.providerEventId, "26224");
  assert.notEqual(eventA.providerEventId, eventB.providerEventId);
});

test("BrevoProvider sends Reply-To and UUID-shaped idempotency header", async () => {
  const provider = new BrevoProvider("api_key", "webhook_secret");
  const originalFetch = globalThis.fetch;
  const originalReplyTo = process.env.EMAIL_REPLY_TO;
  let sentBody: Record<string, unknown> | undefined;

  process.env.EMAIL_REPLY_TO = "contact@ilipresto.fr";
  globalThis.fetch = (async (_url: string | URL | Request, init?: RequestInit) => {
    sentBody = JSON.parse(String(init?.body || "{}")) as Record<string, unknown>;
    return new Response(JSON.stringify({ messageId: "brevo-message-id" }), {
      status: 201,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;

  try {
    const result = await provider.send({
      to: "user@example.com",
      from: "iliprestō <noreply@ilipresto.fr>",
      subject: "Test",
      html: "<p>Test</p>",
      text: "Test",
      tags: ["test"],
      metadata: { event_id: "evt-1" },
      idempotencyKey: "a".repeat(64),
      stream: "transactional",
    });

    assert.equal(result.accepted, true);
    assert.equal(result.providerMessageId, "brevo-message-id");
    assert.deepEqual(sentBody?.replyTo, { email: "contact@ilipresto.fr" });
    const headers = sentBody?.headers as Record<string, string> | undefined;
    assert.match(
      String(headers?.["Idempotency-Key"] || ""),
      /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
  } finally {
    globalThis.fetch = originalFetch;
    if (originalReplyTo === undefined) delete process.env.EMAIL_REPLY_TO;
    else process.env.EMAIL_REPLY_TO = originalReplyTo;
  }
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

test("provider factory prefers Brevo when dual-provider secrets are present without explicit provider", () => {
  withEnv(
    {
      EMAIL_PROVIDER_NAME: undefined,
      BREVO_API_KEY: "brevo_api_key",
      BREVO_WEBHOOK_SECRET: "brevo_webhook_secret",
      EMAIL_PROVIDER_API_KEY: "resend_api_key",
      EMAIL_PROVIDER_WEBHOOK_SECRET: "resend_webhook_secret",
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

test("provider factory rejects explicit resend selection without resend secrets", () => {
  withEnv(
    {
      EMAIL_PROVIDER_NAME: "resend",
      BREVO_API_KEY: "brevo_api_key",
      BREVO_WEBHOOK_SECRET: "brevo_webhook_secret",
      EMAIL_PROVIDER_API_KEY: undefined,
      EMAIL_PROVIDER_WEBHOOK_SECRET: undefined,
    },
    () => {
      assert.throws(
        () => createEmailProvider(),
        /Resend provider selected but EMAIL_PROVIDER_API_KEY\/EMAIL_PROVIDER_WEBHOOK_SECRET are not fully configured/,
      );
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
