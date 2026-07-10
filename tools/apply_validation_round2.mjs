#!/usr/bin/env node

import fs from 'node:fs/promises';

function replaceOnce(content, before, after, label) {
  if (content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

async function patchSubscriptionAudience() {
  const path = 'lib/features/subscriptions/subscription_widgets.dart';
  let content = await fs.readFile(path, 'utf8');
  if (!content.includes('enum OfferAudience { particuliers, pro }')) {
    const count = content.split('_OfferAudience').length - 1;
    if (count < 1) throw new Error('subscription audience type not found');
    content = content.replaceAll('_OfferAudience', 'OfferAudience');
  }
  await fs.writeFile(path, content, 'utf8');
}

async function patchContactChipOverflow() {
  const path = 'lib/pages/toolbox_je_me_lance_page.dart';
  let content = await fs.readFile(path, 'utf8');
  content = replaceOnce(
    content,
    "            Text(\n              label,\n              style: const TextStyle(\n                color: Color(0xFF1A73E8),\n                fontSize: 12,\n                fontWeight: FontWeight.w800,\n              ),\n            ),",
    "            Flexible(\n              child: Text(\n                label,\n                maxLines: 2,\n                overflow: TextOverflow.ellipsis,\n                softWrap: true,\n                style: const TextStyle(\n                  color: Color(0xFF1A73E8),\n                  fontSize: 12,\n                  fontWeight: FontWeight.w800,\n                ),\n              ),\n            ),",
    'task contact chip flexible label',
  );
  await fs.writeFile(path, content, 'utf8');
}

async function patchAuthorityNoOpTest() {
  const path = 'functions/scripts/test_user_authority_rules.mjs';
  let content = await fs.readFile(path, 'utf8');
  content = replaceOnce(
    content,
    "      { accountStatus: 'active' },",
    "      { accountStatus: 'suspended' },",
    'authority account status mutation',
  );
  await fs.writeFile(path, content, 'utf8');
}

await patchSubscriptionAudience();
await patchContactChipOverflow();
await patchAuthorityNoOpTest();
console.log('validation round 2 patches: OK');
