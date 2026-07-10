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

const rulesPath = 'firestore.rules';
let rules = await fs.readFile(rulesPath, 'utf8');
if (!(rules.includes("        'uid',") && rules.includes("        'email',"))) {
  rules = replaceOnce(
    rules,
    "        'accountStatus',\n        'emailVerified',",
    "        'uid',\n        'email',\n        'accountStatus',\n        'emailVerified',",
    'protected identity fields',
  );
}
await fs.writeFile(rulesPath, rules, 'utf8');

const authPath = 'lib/services/auth_service.dart';
let auth = await fs.readFile(authPath, 'utf8');
auth = replaceOnce(auth, "      'uid': user.uid,\n", '', 'remove client uid write');
auth = replaceOnce(auth, "      'email': user.email,\n", '', 'remove client email write');
await fs.writeFile(authPath, auth, 'utf8');

const canonicalPath = 'functions/scripts/test_canonical_marketplace_rules.mjs';
let canonical = await fs.readFile(canonicalPath, 'utf8');
if (!canonical.includes("{ uid: 'another_user' }") ||
    !canonical.includes("{ email: 'attacker@example.com' }")) {
  const marker = "    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { stripeCustomerId: 'cus_fake' }));";
  if (!canonical.includes(marker)) {
    throw new Error('canonical authority marker not found');
  }
  canonical = canonical.replace(
    marker,
    `${marker}\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { uid: 'another_user' }));\n    await assertFails(updateDoc(doc(userDb, 'users', 'user_1'), { email: 'attacker@example.com' }));`,
  );
}
await fs.writeFile(canonicalPath, canonical, 'utf8');

const authorityPath = 'functions/scripts/test_user_authority_rules.mjs';
let authority = await fs.readFile(authorityPath, 'utf8');
if (!authority.includes("{ uid: 'another_user' }") ||
    !authority.includes("{ email: 'attacker@example.com' }")) {
  authority = replaceOnce(
    authority,
    "      { subscriptionPlan: 'ilipro' },",
    "      { uid: 'another_user' },\n      { email: 'attacker@example.com' },\n      { subscriptionPlan: 'ilipro' },",
    'identity authority test cases',
  );
}
await fs.writeFile(authorityPath, authority, 'utf8');

console.log('identity authority hardening: OK');
