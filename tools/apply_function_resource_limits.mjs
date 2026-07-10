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

async function patchListingPhoto() {
  const path = 'functions/src/modules/marketplace/callables/media.ts';
  let content = await fs.readFile(path, 'utf8');
  content = replaceOnce(
    content,
    `  {
    region: PROJECT_REGION,
    timeoutSeconds: 60,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },`,
    `  {
    region: PROJECT_REGION,
    timeoutSeconds: 60,
    memory: "1GiB",
    cpu: 1,
    concurrency: 4,
    maxInstances: 20,
    enforceAppCheck: ENFORCE_APP_CHECK,
  },`,
    'listing photo resources',
  );
  await fs.writeFile(path, content, 'utf8');
}

async function patchConversationPhoto() {
  const path = 'functions/src/modules/messaging/callables.ts';
  let content = await fs.readFile(path, 'utf8');
  content = replaceOnce(
    content,
    `export const processConversationAttachmentPhoto = onCall(
  MESSAGING_CALLABLE_OPTIONS,`,
    `export const processConversationAttachmentPhoto = onCall(
  {
    ...MESSAGING_CALLABLE_OPTIONS,
    timeoutSeconds: 60,
    memory: "512MiB",
    cpu: 1,
    concurrency: 4,
    maxInstances: 20,
  },`,
    'conversation photo resources',
  );
  await fs.writeFile(path, content, 'utf8');
}

await patchListingPhoto();
await patchConversationPhoto();
console.log('function resource limits: OK');
