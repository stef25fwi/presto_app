#!/usr/bin/env node

import fs from 'node:fs/promises';

// Startup moved out of lib/main.dart during architecture lot 2. Keep this
// hardening guard aligned with the real startup owner so CI remains idempotent.
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
  '    // La typographie distante ne bloque plus le premier rendu.\n    unawaited(typographySettings.load());',
  'typography startup',
);

replaceOnce(
  '    await CookieConsentService.instance.load();',
  '    // Le consentement est chargé en parallèle et l’UI réagit à son état.\n    unawaited(CookieConsentService.instance.load());',
  'cookie consent startup',
);

await fs.writeFile(path, content, 'utf8');
console.log('startup hardening patches: OK');
