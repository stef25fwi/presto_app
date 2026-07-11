#!/usr/bin/env node

import fs from 'node:fs/promises';

const patchPath = 'tools/apply_account_compact_spacing.mjs';
let content = await fs.readFile(patchPath, 'utf8');

const before = `function replaceOnce(content, before, after, label) {
  if (content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(\`${'${label}'}: expected exactly one occurrence, found ${'${count}'}\`);
  }
  return content.replace(before, after);
}`;

const after = `function replaceOnce(content, before, after, label) {
  const count = content.split(before).length - 1;
  if (count === 0 && content.includes(after)) return content;
  if (count !== 1) {
    throw new Error(\`${'${label}'}: expected exactly one occurrence, found ${'${count}'}\`);
  }
  return content.replace(before, after);
}`;

if (content.includes(before)) {
  content = content.replace(before, after);
  await fs.writeFile(patchPath, content, 'utf8');
} else if (!content.includes(after)) {
  throw new Error('account compact spacing helper not found');
}

await import('./apply_account_compact_spacing.mjs');
