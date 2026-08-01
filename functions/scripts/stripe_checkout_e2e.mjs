#!/usr/bin/env node
/**
 * Parcours Checkout de bout en bout contre Stripe en mode test.
 *
 * Ce que les tests unitaires ne peuvent pas prouver : que la clé configurée
 * ouvre bien un compte utilisable, que les identifiants de tarif existent chez
 * Stripe avec le bon montant, et qu'une session Checkout réelle se crée puis
 * s'ouvre. C'est le seul contrôle de la phase 11 qui exige un vrai appel
 * réseau — d'où un script à lancer à la main plutôt qu'un test automatisé.
 *
 * Le script REFUSE de s'exécuter avec une clé `sk_live_` : il crée des objets
 * dans le compte visé, ce qui n'a rien à faire en production.
 *
 * Usage :
 *   STRIPE_SECRET_KEY=sk_test_... \
 *   STRIPE_PRICE_ILIPRESTO_PLUS=price_... \
 *   STRIPE_PRICE_ILIPRO=price_... \
 *   node scripts/stripe_checkout_e2e.mjs [--keep]
 *
 * `--keep` conserve le client de test créé ; par défaut il est supprimé.
 */

const API = "https://api.stripe.com";

const EXPECTED_PRICES = {
  ilipresto_plus: { amount: 199, currency: "eur", interval: "month" },
  ilipro: { amount: 999, currency: "eur", interval: "month" },
};

function fail(message) {
  console.error(`ÉCHEC — ${message}`);
  process.exitCode = 1;
  throw new Error(message);
}

function requireEnv(name) {
  const value = String(process.env[name] ?? "").trim();
  if (!value) fail(`variable ${name} absente`);
  return value;
}

async function stripe(method, path, params, secret) {
  const response = await fetch(`${API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${secret}`,
      ...(params ? { "Content-Type": "application/x-www-form-urlencoded" } : {}),
    },
    body: params ? new URLSearchParams(params).toString() : undefined,
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    fail(`${method} ${path} → ${response.status} ${payload?.error?.message ?? ""}`);
  }
  return payload;
}

function checkPrice(plan, price) {
  const expected = EXPECTED_PRICES[plan];
  const problems = [];

  if (price.unit_amount !== expected.amount) {
    problems.push(`montant ${price.unit_amount} attendu ${expected.amount}`);
  }
  if (String(price.currency).toLowerCase() !== expected.currency) {
    problems.push(`devise ${price.currency} attendue ${expected.currency}`);
  }
  if (price.recurring?.interval !== expected.interval) {
    problems.push(`intervalle ${price.recurring?.interval} attendu ${expected.interval}`);
  }
  if (price.active !== true) {
    problems.push("tarif inactif chez Stripe");
  }

  return problems;
}

async function main() {
  const secret = requireEnv("STRIPE_SECRET_KEY");
  if (!secret.startsWith("sk_test_")) {
    fail("ce script n'accepte qu'une clé sk_test_ : il crée des objets Stripe");
  }

  const priceIds = {
    ilipresto_plus: requireEnv("STRIPE_PRICE_ILIPRESTO_PLUS"),
    ilipro: requireEnv("STRIPE_PRICE_ILIPRO"),
  };

  const account = await stripe("GET", "/v1/account", null, secret);
  console.log(`Compte Stripe : ${account.id} (${account.settings?.dashboard?.display_name ?? "sans nom"})`);

  for (const [plan, priceId] of Object.entries(priceIds)) {
    const price = await stripe("GET", `/v1/prices/${encodeURIComponent(priceId)}`, null, secret);
    const problems = checkPrice(plan, price);
    if (problems.length > 0) {
      fail(`tarif ${plan} (${priceId}) : ${problems.join(", ")}`);
    }
    console.log(`Tarif ${plan} conforme : ${price.unit_amount / 100} ${price.currency.toUpperCase()}/${price.recurring.interval}`);
  }

  const uid = `e2e_${Date.now()}`;
  const customer = await stripe("POST", "/v1/customers", {
    email: `${uid}@example.test`,
    "metadata[firebaseUid]": uid,
    "metadata[source]": "stripe_checkout_e2e",
  }, secret);
  console.log(`Client de test créé : ${customer.id}`);

  try {
    const session = await stripe("POST", "/v1/checkout/sessions", {
      mode: "subscription",
      customer: customer.id,
      client_reference_id: uid,
      "line_items[0][price]": priceIds.ilipresto_plus,
      "line_items[0][quantity]": "1",
      "metadata[plan]": "ilipresto_plus",
      "metadata[firebaseUid]": uid,
      "subscription_data[metadata][plan]": "ilipresto_plus",
      "subscription_data[metadata][firebaseUid]": uid,
      success_url: "https://ilipresto.fr/account?subscription=success&session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://ilipresto.fr/account?subscription=cancel",
    }, secret);

    if (!session.url) fail("session Checkout créée sans URL");
    if (session.status !== "open") fail(`session Checkout en statut ${session.status}`);

    console.log(`Session Checkout ouverte : ${session.id}`);
    console.log(`URL de paiement : ${session.url}`);
    console.log("");
    console.log("Étapes manuelles restantes pour clore le contrôle :");
    console.log("  1. Ouvrir l'URL, payer avec la carte de test 4242 4242 4242 4242.");
    console.log("  2. Vérifier dans Firestore que subscriptions/<sub_id> passe en actif");
    console.log(`     et que users/${uid} porte subscriptionPlan=iliprestoPlus.`);
    console.log("  3. Vérifier que stripe_webhook_events contient l'événement, en statut processed.");
    console.log("  4. Rejouer l'événement depuis le dashboard Stripe et vérifier qu'il est marqué duplicate.");
  } finally {
    if (!process.argv.includes("--keep")) {
      await stripe("DELETE", `/v1/customers/${customer.id}`, null, secret).catch(() => {});
      console.log(`Client de test supprimé : ${customer.id}`);
    }
  }
}

main().catch((error) => {
  if (process.exitCode !== 1) {
    console.error(error);
    process.exitCode = 1;
  }
});
