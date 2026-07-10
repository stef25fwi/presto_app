#!/usr/bin/env node

import fs from 'node:fs/promises';

function replaceOnce(content, before, after, label) {
  if (after && content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (!after && count === 0) return content;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

async function patchStripeWebhook() {
  const path = 'functions/src/modules/billing/stripe_webhook.ts';
  let content = await fs.readFile(path, 'utf8');
  content = replaceOnce(
    content,
    '    if (!snap.empty) return snap.docs[0].id;',
    '    const firstDocument = snap.docs[0];\n    if (firstDocument) return firstDocument.id;',
    'stripe first query document',
  );
  await fs.writeFile(path, content, 'utf8');
}

async function patchCanonicalRulesTest() {
  const path = 'functions/scripts/test_canonical_marketplace_rules.mjs';
  let content = await fs.readFile(path, 'utf8');
  content = replaceOnce(
    content,
    "    await assertFails(setDoc(doc(userDb, 'users', 'user_1'), { displayName: 'X' }));\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { displayName: 'Y' }));",
    "    // Les champs de profil ordinaires restent modifiables par leur propriétaire.\n    await assertSucceeds(setDoc(doc(userDb, 'users', 'user_1'), { displayName: 'X' }));\n    await assertSucceeds(updateDoc(doc(userDb, 'users', 'user_1'), { displayName: 'Y' }));",
    'canonical safe profile writes',
  );
  await fs.writeFile(path, content, 'utf8');
}

async function patchAuthScriptIdempotence() {
  const path = 'tools/apply_auth_client_hardening.mjs';
  let content = await fs.readFile(path, 'utf8');
  content = replaceOnce(
    content,
    "  const count = content.split(before).length - 1;\n  if (count !== 1) {",
    "  const count = content.split(before).length - 1;\n  if (!after && count === 0) return content;\n  if (count !== 1) {",
    'auth script empty replacement idempotence',
  );
  await fs.writeFile(path, content, 'utf8');
}

async function patchFlutterWorkflow(path, { validationBuild = false } = {}) {
  let content = await fs.readFile(path, 'utf8');
  content = content
    .replaceAll('Setup Flutter 3.41.4', 'Setup Flutter 3.44.6')
    .replaceAll("flutter-version: '3.41.4'", "flutter-version: '3.44.6'");

  if (validationBuild) {
    content = content.replaceAll(
      'bash tools/flutter_with_build_stamp.sh build web --release --no-wasm-dry-run',
      'APPCHECK_RECAPTCHA_SITE_KEY=audit-placeholder-site-key bash tools/flutter_with_build_stamp.sh build web --release --no-wasm-dry-run',
    );
  }

  await fs.writeFile(path, content, 'utf8');
}

await patchStripeWebhook();
await patchCanonicalRulesTest();
await patchAuthScriptIdempotence();
await patchFlutterWorkflow('.github/workflows/deploy.yml');
await patchFlutterWorkflow('.github/workflows/pr-validation.yml', {
  validationBuild: true,
});
await patchFlutterWorkflow('.github/workflows/audit-branch-validation.yml', {
  validationBuild: true,
});

console.log('validation fixes: OK');
