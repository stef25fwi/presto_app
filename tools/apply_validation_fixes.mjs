#!/usr/bin/env node

import fs from 'node:fs/promises';

async function read(path) {
  return fs.readFile(path, 'utf8');
}

async function write(path, content) {
  await fs.writeFile(path, content, 'utf8');
}

function replaceOnce(content, before, after, label) {
  if (after && content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (!after && count === 0) return content;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one source occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

async function patchStripeWebhook() {
  const path = 'functions/src/modules/billing/stripe_webhook.ts';
  let content = await read(path);
  content = replaceOnce(
    content,
    '    if (!snap.empty) return snap.docs[0].id;',
    '    const firstDocument = snap.docs[0];\n    if (firstDocument) return firstDocument.id;',
    'Stripe user lookup with noUncheckedIndexedAccess',
  );
  await write(path, content);
}

async function patchCanonicalRulesTest() {
  const path = 'functions/scripts/test_canonical_marketplace_rules.mjs';
  let content = await read(path);
  content = replaceOnce(
    content,
    "    await assertFails(setDoc(doc(userDb, 'users', 'user_1'), { displayName: 'X' }));\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { displayName: 'Y' }));",
    "    // Les champs de profil ordinaires restent modifiables par leur propriétaire.\n    await assertSucceeds(updateDoc(doc(userDb, 'users', 'user_1'), { displayName: 'Y' }));\n    // Les droits premium, identifiants Stripe et vérifications restent serveur-only.\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), {\n      subscriptionPlan: 'ilipro',\n      subscriptionStatus: 'active',\n    }));\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { proVerified: true }));\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { stripeCustomerId: 'cus_fake' }));",
    'canonical user authority expectations',
  );
  content = replaceOnce(
    content,
    "    // Les champs de profil ordinaires restent modifiables par leur propriétaire.\n    await assertSucceeds(setDoc(doc(userDb, 'users', 'user_1'), { displayName: 'X' }));\n    await assertSucceeds(updateDoc(doc(userDb, 'users', 'user_1'), { displayName: 'Y' }));",
    "    // Les champs de profil ordinaires restent modifiables par leur propriétaire.\n    await assertSucceeds(updateDoc(doc(userDb, 'users', 'user_1'), { displayName: 'Y' }));\n    // Les droits premium, identifiants Stripe et vérifications restent serveur-only.\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), {\n      subscriptionPlan: 'ilipro',\n      subscriptionStatus: 'active',\n    }));\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { proVerified: true }));\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { stripeCustomerId: 'cus_fake' }));",
    'canonical user authority expectations after first patch',
  );
  await write(path, content);
}

async function patchAuthHardeningScript() {
  const path = 'tools/apply_auth_client_hardening.mjs';
  let content = await read(path);
  content = replaceOnce(
    content,
    "  const count = content.split(before).length - 1;\n  if (count !== 1) {",
    "  const count = content.split(before).length - 1;\n  if (!after && count === 0) return content;\n  if (count !== 1) {",
    'auth patch empty replacement idempotence',
  );
  await write(path, content);
}

async function patchAuditWorkflow() {
  const path = '.github/workflows/audit-branch-validation.yml';
  let content = await read(path);
  content = content
    .replaceAll('Setup Flutter 3.41.4', 'Setup Flutter 3.44.6')
    .replaceAll("flutter-version: '3.41.4'", "flutter-version: '3.44.6'");
  content = replaceOnce(
    content,
    '          node tools/apply_account_cleanup_patch.mjs 2>&1 | tee -a audit_validation_logs/patches.log\n',
    '          node tools/apply_account_cleanup_patch.mjs 2>&1 | tee -a audit_validation_logs/patches.log\n          node tools/apply_validation_fixes.mjs 2>&1 | tee -a audit_validation_logs/patches.log\n',
    'audit workflow verifies validation fixes',
  );
  content = replaceOnce(
    content,
    '          bash tools/flutter_with_build_stamp.sh build web --release --no-wasm-dry-run 2>&1 | tee audit_validation_logs/web_build.log',
    '          APPCHECK_RECAPTCHA_SITE_KEY=ci-audit-placeholder bash tools/flutter_with_build_stamp.sh build web --release --no-wasm-dry-run 2>&1 | tee audit_validation_logs/web_build.log',
    'audit workflow App Check build placeholder',
  );
  await write(path, content);
}

async function patchPrWorkflow() {
  const path = '.github/workflows/pr-validation.yml';
  let content = await read(path);
  content = content.replaceAll("flutter-version: '3.41.4'", "flutter-version: '3.44.6'");
  content = replaceOnce(
    content,
    "          node tools/apply_prod_hardening_patches.mjs\n          git diff --exit-code\n          node tools/check_production_guardrails.mjs",
    "          node tools/apply_prod_hardening_patches.mjs\n          node tools/apply_startup_hardening.mjs\n          node tools/apply_auth_client_hardening.mjs\n          node tools/apply_account_cleanup_patch.mjs\n          node tools/apply_validation_fixes.mjs\n          git diff --exit-code\n          node tools/check_production_guardrails.mjs",
    'PR workflow verifies all generated patches',
  );
  content = replaceOnce(
    content,
    '        run: bash tools/flutter_with_build_stamp.sh build web --release --no-wasm-dry-run',
    '        run: APPCHECK_RECAPTCHA_SITE_KEY=ci-pr-placeholder bash tools/flutter_with_build_stamp.sh build web --release --no-wasm-dry-run',
    'PR workflow App Check build placeholder',
  );
  await write(path, content);
}

async function patchDeployWorkflow() {
  const path = '.github/workflows/deploy.yml';
  let content = await read(path);
  content = content
    .replaceAll('Setup Flutter 3.41.4', 'Setup Flutter 3.44.6')
    .replaceAll("flutter-version: '3.41.4'", "flutter-version: '3.44.6'");
  content = replaceOnce(
    content,
    "          node tools/apply_prod_hardening_patches.mjs\n          git diff --exit-code",
    "          node tools/apply_prod_hardening_patches.mjs\n          node tools/apply_startup_hardening.mjs\n          node tools/apply_auth_client_hardening.mjs\n          node tools/apply_account_cleanup_patch.mjs\n          node tools/apply_validation_fixes.mjs\n          git diff --exit-code\n          node tools/check_production_guardrails.mjs",
    'deploy verifies all generated patches',
  );
  await write(path, content);
}

async function main() {
  await patchStripeWebhook();
  await patchCanonicalRulesTest();
  await patchAuthHardeningScript();
  await patchAuditWorkflow();
  await patchPrWorkflow();
  await patchDeployWorkflow();
  console.log('validation fixes: OK');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
