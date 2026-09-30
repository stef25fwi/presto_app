import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import test from "node:test";
import { ResendProvider } from "./resend_provider";

const secretBytes = Buffer.from("synthetic-webhook-test-secret");
const provider = new ResendProvider("unused", `whsec_${secretBytes.toString("base64")}`);
const body = '{"type":"email.delivered"}';
function headers(timestamp = String(Math.floor(Date.now() / 1000))) {
  const signature = createHmac("sha256", secretBytes)
    .update(`msg_fixture.${timestamp}.${body}`).digest("base64");
  return { "svix-id": "msg_fixture", "svix-timestamp": timestamp, "svix-signature": `v1,${signature}` };
}
test("Resend authenticates a recent delivery and rotated signatures", () => {
  const valid = headers();
  assert.equal(provider.verifyWebhookSignature(valid, body), true);
  assert.equal(provider.verifyWebhookSignature({ ...valid, "svix-signature": `v1,bad ${valid["svix-signature"]}` }, body), true);
});
test("Resend rejects signed expired and future deliveries", () => {
  const now = Math.floor(Date.now() / 1000);
  for (const offset of [-600, 600]) assert.equal(provider.verifyWebhookSignature(headers(String(now + offset)), body), false);
});
test("Resend rejects malformed timestamps, version and changed payload", () => {
  for (const timestamp of ["Infinity", "1e9", "NaN", "", "9007199254740993"]) {
    assert.equal(provider.verifyWebhookSignature(headers(timestamp), body), false);
  }
  const valid = headers();
  assert.equal(provider.verifyWebhookSignature(valid, body + " "), false);
  assert.equal(provider.verifyWebhookSignature({ ...valid, "svix-signature": valid["svix-signature"].replace("v1,", "v2,") }, body), false);
  assert.equal(provider.verifyWebhookSignature({ ...valid, "svix-signature": "v1,a" }, body), false);
});
