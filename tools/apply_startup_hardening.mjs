#!/usr/bin/env node

import fs from 'node:fs/promises';

// Startup moved out of lib/main.dart during architecture lot 2. Keep this
// hardening guard aligned with the real startup owner and make it idempotent
// even when comments are moved by later architecture refactors.
const path = 'lib/bootstrap/app_bootstrap.dart';
let content = await fs.readFile(path, 'utf8');

function replaceOnce(before, after, label) {
  if (content.includes(after)) return;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  content = content.replace(before, after);
}

replaceOnce(
  '    await typographySettings.load();',
  '    unawaited(typographySettings.load());',
  'typography startup',
);

replaceOnce(
  '    await CookieConsentService.instance.load();',
  '    unawaited(CookieConsentService.instance.load());',
  'cookie consent startup',
);

await fs.writeFile(path, content, 'utf8');
console.log('startup hardening patches: OK');
