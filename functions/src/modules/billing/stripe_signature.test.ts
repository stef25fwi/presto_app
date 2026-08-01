import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import test from "node:test";

import { latestRefundOfCharge, verifyStripeSignature } from "./stripe_webhook";

const SECRET = "whsec_test_secret";

function sign(body: string, timestampSeconds: number, secret = SECRET): string {
  const signature = createHmac("sha256", secret)
    .update(`${timestampSeconds}.${body}`)
    .digest("hex");
  return `t=${timestampSeconds},v1=${signature}`;
}

function nowSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

const payload = JSON.stringify({
  id: "evt_1",
  type: "checkout.session.completed",
  livemode: false,
  created: 1_700_000_000,
  data: { object: { id: "cs_1", subscription: "sub_1" } },
});

test("une charge utile correctement signée est acceptée", () => {
  const timestamp = nowSeconds();
  assert.doesNotThrow(() => {
    verifyStripeSignature(Buffer.from(payload), sign(payload, timestamp), SECRET);
  });
});

test("un corps modifié après signature est rejeté", () => {
  const timestamp = nowSeconds();
  const header = sign(payload, timestamp);
  const tampered = payload.replace("cs_1", "cs_2");

  assert.throws(
    () => verifyStripeSignature(Buffer.from(tampered), header, SECRET),
    /Signature Stripe incorrecte/,
  );
});

test("une signature d'un autre secret est rejetée", () => {
  // Cas concret : le secret du webhook de test recopié en production.
  const timestamp = nowSeconds();
  const header = sign(payload, timestamp, "whsec_autre_environnement");

  assert.throws(
    () => verifyStripeSignature(Buffer.from(payload), header, SECRET),
    /Signature Stripe incorrecte/,
  );
});

test("un rejeu hors de la fenêtre de tolérance est rejeté", () => {
  const old = nowSeconds() - 10 * 60;
  assert.throws(
    () => verifyStripeSignature(Buffer.from(payload), sign(payload, old), SECRET),
    /Signature Stripe expirée/,
  );
});

test("un horodatage futur hors tolérance est aussi rejeté", () => {
  const ahead = nowSeconds() + 10 * 60;
  assert.throws(
    () => verifyStripeSignature(Buffer.from(payload), sign(payload, ahead), SECRET),
    /Signature Stripe expirée/,
  );
});

test("un en-tête absent, vide ou malformé est rejeté", () => {
  for (const header of ["", "v1=abc", "t=123", "n'importe quoi"]) {
    assert.throws(
      () => verifyStripeSignature(Buffer.from(payload), header, SECRET),
      /Signature Stripe absente ou invalide|Horodatage Stripe invalide/,
      `en-tête accepté à tort: ${header}`,
    );
  }
});

test("un horodatage non numérique est rejeté", () => {
  assert.throws(
    () => verifyStripeSignature(Buffer.from(payload), "t=abc,v1=def", SECRET),
    /Horodatage Stripe invalide/,
  );
});

test("plusieurs signatures v1 sont acceptées si l'une est valide", () => {
  // Stripe en émet deux pendant une rotation de secret.
  const timestamp = nowSeconds();
  const valid = sign(payload, timestamp).split("v1=")[1];
  const header = `t=${timestamp},v1=${"0".repeat(64)},v1=${valid}`;

  assert.doesNotThrow(() => {
    verifyStripeSignature(Buffer.from(payload), header, SECRET);
  });
});

test("le dernier remboursement d'une charge est le plus récent", () => {
  const charge = {
    refunds: {
      data: [
        { id: "re_ancien", created: 100 },
        { id: "re_recent", created: 300 },
        { id: "re_median", created: 200 },
      ],
    },
  };
  assert.equal(latestRefundOfCharge(charge).id, "re_recent");
});

test("une charge sans remboursement ne casse pas le traitement", () => {
  assert.deepEqual(latestRefundOfCharge({}), {});
  assert.deepEqual(latestRefundOfCharge({ refunds: { data: [] } }), {});
});
