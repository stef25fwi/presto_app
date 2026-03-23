"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_crypto_1 = require("node:crypto");
const node_test_1 = __importDefault(require("node:test"));
const brevo_provider_1 = require("./brevo_provider");
const provider_factory_1 = require("./provider_factory");
function withEnv(vars, run) {
    const previous = new Map();
    for (const [key, value] of Object.entries(vars)) {
        previous.set(key, process.env[key]);
        if (value === undefined) {
            delete process.env[key];
        }
        else {
            process.env[key] = value;
        }
    }
    try {
        run();
    }
    finally {
        for (const [key, value] of previous.entries()) {
            if (value === undefined) {
                delete process.env[key];
            }
            else {
                process.env[key] = value;
            }
        }
    }
}
(0, node_test_1.default)("BrevoProvider verifies x-mailin-signature", () => {
    const secret = "brevo_webhook_secret";
    const rawBody = JSON.stringify({ event: "delivered", email: "user@example.com" });
    const signature = (0, node_crypto_1.createHmac)("sha256", secret).update(rawBody).digest("hex");
    const provider = new brevo_provider_1.BrevoProvider("api_key", secret);
    strict_1.default.equal(provider.verifyWebhookSignature({ "x-mailin-signature": signature }, rawBody), true);
    strict_1.default.equal(provider.verifyWebhookSignature({ "x-mailin-signature": "bad" }, rawBody), false);
});
(0, node_test_1.default)("BrevoProvider verifies sha256= prefixed signature", () => {
    const secret = "brevo_webhook_secret";
    const rawBody = JSON.stringify({ event: "opened", email: "user@example.com" });
    const signature = (0, node_crypto_1.createHmac)("sha256", secret).update(rawBody).digest("hex");
    const provider = new brevo_provider_1.BrevoProvider("api_key", secret);
    strict_1.default.equal(provider.verifyWebhookSignature({ "x-mailin-signature": `sha256=${signature}` }, rawBody), true);
});
(0, node_test_1.default)("BrevoProvider parses Brevo webhook events", () => {
    const provider = new brevo_provider_1.BrevoProvider("api_key", "webhook_secret");
    const [event] = provider.parseWebhook({
        event: "hard_bounce",
        email: "user@example.com",
        "message-id": "brevo-message-1",
    });
    strict_1.default.ok(event);
    strict_1.default.equal(event.type, "bounced");
    strict_1.default.equal(event.recipient, "user@example.com");
    strict_1.default.equal(event.providerMessageId, "brevo-message-1");
});
(0, node_test_1.default)("BrevoProvider parses event timestamp from payload", () => {
    const provider = new brevo_provider_1.BrevoProvider("api_key", "webhook_secret");
    const [event] = provider.parseWebhook({
        event: "delivered",
        email: "user@example.com",
        "message-id": "brevo-message-2",
        timestamp: "1700000000",
    });
    strict_1.default.ok(event);
    strict_1.default.equal(event.occurredAt, 1700000000 * 1000);
});
(0, node_test_1.default)("provider factory auto-selects Brevo when BREVO_API_KEY is present", () => {
    withEnv({
        EMAIL_PROVIDER_NAME: undefined,
        BREVO_API_KEY: "brevo_api_key",
        BREVO_WEBHOOK_SECRET: "brevo_webhook_secret",
        EMAIL_PROVIDER_API_KEY: undefined,
        EMAIL_PROVIDER_WEBHOOK_SECRET: undefined,
    }, () => {
        const provider = (0, provider_factory_1.createEmailProvider)();
        strict_1.default.equal(provider.name(), "brevo");
    });
});
(0, node_test_1.default)("provider factory honors explicit resend selection", () => {
    withEnv({
        EMAIL_PROVIDER_NAME: "resend",
        BREVO_API_KEY: "brevo_api_key",
        BREVO_WEBHOOK_SECRET: "brevo_webhook_secret",
        EMAIL_PROVIDER_API_KEY: "resend_api_key",
        EMAIL_PROVIDER_WEBHOOK_SECRET: "resend_webhook_secret",
    }, () => {
        const provider = (0, provider_factory_1.createEmailProvider)();
        strict_1.default.equal(provider.name(), "resend");
    });
});
(0, node_test_1.default)("provider factory rejects unsupported explicit provider", () => {
    withEnv({
        EMAIL_PROVIDER_NAME: "mailjet",
        BREVO_API_KEY: "brevo_api_key",
        BREVO_WEBHOOK_SECRET: "brevo_webhook_secret",
        EMAIL_PROVIDER_API_KEY: "resend_api_key",
        EMAIL_PROVIDER_WEBHOOK_SECRET: "resend_webhook_secret",
    }, () => {
        strict_1.default.throws(() => (0, provider_factory_1.createEmailProvider)(), /Unsupported EMAIL_PROVIDER_NAME/);
    });
});
//# sourceMappingURL=brevo_provider.test.js.map