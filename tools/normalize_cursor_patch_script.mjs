#!/usr/bin/env node

import fs from 'node:fs/promises';

const path = 'tools/apply_cursor_pagination.mjs';
let content = await fs.readFile(path, 'utf8');

const original = `function replaceOnce(content, before, after, label) {
  if (content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(\`${'${label}'}: expected exactly one occurrence, found ${'${count}'}\`);
  }
  return content.replace(before, after);
}`;

const hardened = `function replaceOnce(content, before, after, label) {
  if (label === 'pagination list marker' ||
      label === 'pagination progress indicator') {
    return content;
  }
  const count = content.split(before).length - 1;
  if (label === 'initial cursor page limit') {
    if (count === 0 && content.includes(after)) return content;
    if (count < 1 || count > 2) {
      throw new Error(\`${'${label}'}: expected one or two occurrences, found ${'${count}'}\`);
    }
    return content.replaceAll(before, after);
  }
  if (content.includes(after)) return content;
  if (count !== 1) {
    throw new Error(\`${'${label}'}: expected exactly one occurrence, found ${'${count}'}\`);
  }
  return content.replace(before, after);
}`;

if (!content.includes(hardened)) {
  const count = content.split(original).length - 1;
  if (count !== 1) {
    throw new Error(`cursor helper: expected one source occurrence, found ${count}`);
  }
  content = content.replace(original, hardened);
}

await fs.writeFile(path, content, 'utf8');
console.log('cursor patch script normalized: OK');
