#!/usr/bin/env node

import fs from 'node:fs/promises';

const checks = [
  {
    file: 'firestore.rules',
    forbidden: 'allow delete: if isSignedIn() && userId == uid();',
    message: 'users/{uid} must not be directly deletable by clients',
  },
  {
    file: 'firestore.rules',
    required: "'subscriptionPlan'",
    message: 'subscriptionPlan must remain a protected user field',
  },
  {
    file: 'firestore.rules',
    required: "'proVerified'",
    message: 'proVerified must remain a protected user field',
  },
  {
    file: 'lib/services/app_monitoring_service.dart',
    forbidden: "collection('app_monitoring_events').add",
    message: 'client monitoring events must go through a callable',
  },
  {
    file: 'lib/services/app_monitoring_service.dart',
    required: "name: 'reportClientMonitoringEvent'",
    message: 'client monitoring callable is not wired',
  },
  {
    file: 'lib/services/public_offers_query_helpers.dart',
    forbidden: 'Dernier secours : fetch public non filtré',
    message: 'public browse must not fall back to unfiltered reads',
  },
  {
    file: 'test/toolbox_je_me_lance_etudiant_journey_test.dart',
    forbidden: "message.contains('RenderFlex overflowed')",
    message: 'layout errors must not be swallowed by tests',
  },
  {
    file: 'functions/src/core/rate_limit.ts',
    required: 'expiresAt:',
    message: 'rate-limit documents must carry a TTL field',
  },
  {
    file: 'functions/src/config/env.ts',
    required: 'defineSecret("STRIPE_PRICE_ILIPRESTO_PLUS")',
    message: 'ilipresto+ Stripe Price ID must remain a bound runtime secret',
  },
  {
    file: 'functions/src/config/env.ts',
    required: 'defineSecret("STRIPE_PRICE_ILIPRO")',
    message: 'ilipro Stripe Price ID must remain a bound runtime secret',
  },
  {
    file: 'functions/src/modules/billing/callables.ts',
    required: 'secrets: STRIPE_CHECKOUT_SECRETS',
    message: 'checkout callable must bind both Stripe Price ID secrets',
  },
  {
    file: 'functions/src/modules/billing/callables.ts',
    required: 'priceId.startsWith("price_")',
    message: 'checkout must validate Stripe Price ID format',
  },
  {
    file: 'functions/src/modules/billing/callables.ts',
    required: 'DEFAULT_STRIPE_RETURN_BASE_URL = "https://ilipresto.web.app"',
    message: 'Stripe must return to the canonical ilipresto web application',
  },
  {
    file: 'functions/src/modules/billing/callables.ts',
    required: 'url.searchParams.set("section", "subscriptions")',
    message: 'Stripe return URLs must target the subscriptions section',
  },
  {
    file: 'lib/features/subscriptions/subscription_checkout_service.dart',
    required: 'prepareSubscriptionReturnHistory',
    message:
      'web checkout must keep the subscriptions-page history preparer wired',
  },
];

async function main() {
  const failures = [];

  for (const check of checks) {
    const content = await fs.readFile(check.file, 'utf8');
    if (check.required && !content.includes(check.required)) {
      failures.push(`${check.file}: ${check.message}`);
    }
    if (check.forbidden && content.includes(check.forbidden)) {
      failures.push(`${check.file}: ${check.message}`);
    }
  }

  if (failures.length > 0) {
    console.error('Production guardrails failed:');
    for (const failure of failures) console.error(`- ${failure}`);
    process.exitCode = 1;
    return;
  }

  console.log(`production guardrails: OK (${checks.length} checks)`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
