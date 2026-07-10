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
