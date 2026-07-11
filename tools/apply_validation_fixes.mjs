#!/usr/bin/env node

import fs from 'node:fs/promises';

async function read(path) {
  return fs.readFile(path, 'utf8');
}

async function write(path, content) {
  await fs.writeFile(path, content, 'utf8');
}

function replaceRequired(content, before, after, doneMarker, label) {
  if (doneMarker && content.includes(doneMarker)) return content;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one source occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

async function verifyStripeWebhook() {
  const path = 'functions/src/modules/billing/stripe_webhook.ts';
  let content = await read(path);
  content = replaceRequired(
    content,
    '    if (!snap.empty) return snap.docs[0].id;',
    '    const firstDocument = snap.docs[0];\n    if (firstDocument) return firstDocument.id;',
    'const firstDocument = snap.docs[0];',
    'Stripe user lookup with noUncheckedIndexedAccess',
  );
  await write(path, content);
}

async function verifyCanonicalRulesTest() {
  const path = 'functions/scripts/test_canonical_marketplace_rules.mjs';
  const content = await read(path);
  const markers = [
    "subscriptionPlan: 'ilipro'",
    "proVerified: true",
    "stripeCustomerId: 'cus_fake'",
    "assertSucceeds(updateDoc(doc(userDb, 'users', 'user_1')",
  ];
  const missing = markers.filter((marker) => !content.includes(marker));
  if (missing.length > 0) {
    throw new Error(`canonical rules test is missing authority assertions: ${missing.join(', ')}`);
  }
}

async function verifyAuthPatchScript() {
  const path = 'tools/apply_auth_client_hardening.mjs';
  const content = await read(path);
  if (!content.includes('if (!after && count === 0) return content;')) {
    throw new Error('auth client patch must tolerate an already removed field');
  }
}

async function normalizeWorkflow(path, { requireCiAppCheck = false } = {}) {
  let content = await read(path);
  content = content
    .replaceAll('Setup Flutter 3.41.4', 'Setup Flutter 3.44.6')
    .replaceAll("flutter-version: '3.41.4'", "flutter-version: '3.44.6'");

  if (!content.includes("flutter-version: '3.44.6'")) {
    throw new Error(`${path}: Flutter 3.44.6 is required`);
  }

  if (requireCiAppCheck && !content.includes('APPCHECK_RECAPTCHA_SITE_KEY: ci-')) {
    throw new Error(`${path}: CI App Check build value is missing`);
  }

  if (!content.includes('node tools/apply_validation_fixes.mjs')) {
    throw new Error(`${path}: validation fixes are not verified by the workflow`);
  }

  await write(path, content);
}

await verifyStripeWebhook();
await verifyCanonicalRulesTest();
await verifyAuthPatchScript();
await normalizeWorkflow('.github/workflows/deploy.yml');
await normalizeWorkflow('.github/workflows/pr-validation.yml', {
  requireCiAppCheck: true,
});
await normalizeWorkflow('.github/workflows/audit-branch-validation.yml', {
  requireCiAppCheck: true,
});

await import('./apply_account_compact_spacing.mjs');

console.log('validation fixes: OK');
