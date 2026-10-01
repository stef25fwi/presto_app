#!/usr/bin/env node

import fs from 'node:fs/promises';

const path = 'functions/src/modules/auth/account_deletion.ts';
let content = await fs.readFile(path, 'utf8');

// The cleanup is already part of the branch after the Store account-deletion
// change. Keep this generator idempotent so CI does not try to patch it twice.
if (content.includes('archiveUserListings(uid)')) {
  console.log('account cleanup patch: already applied');
  process.exit(0);
}

function replaceOnce(before, after, label) {
  if (content.includes(after)) return;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  content = content.replace(before, after);
}

replaceOnce(
  'import { logger } from "../../core/logger";\n',
  'import { logger } from "../../core/logger";\nimport { archiveUserListings } from "./account_deletion_cleanup";\n',
  'account cleanup import',
);

replaceOnce(
  '    const [deletedDocuments, anonymizedConversations] = await Promise.all([\n      deleteUserOwnedDocuments(uid),\n      anonymizeConversations(uid),\n    ]);\n    await deleteUserStorage(uid);',
  '    const [deletedDocuments, anonymizedConversations, archivedListings] =\n      await Promise.all([\n        deleteUserOwnedDocuments(uid),\n        anonymizeConversations(uid),\n        archiveUserListings(uid),\n      ]);\n    await deleteUserStorage(uid);',
  'account cleanup execution',
);

replaceOnce(
  '      anonymizedConversations,\n      stripeSubscriptionCanceled: Boolean(subscriptionId),',
  '      anonymizedConversations,\n      archivedListings,\n      stripeSubscriptionCanceled: Boolean(subscriptionId),',
  'account cleanup log',
);

replaceOnce(
  '      anonymizedConversations,\n    };',
  '      anonymizedConversations,\n      archivedListings,\n    };',
  'account cleanup result',
);

await fs.writeFile(path, content, 'utf8');
console.log('account cleanup patch: OK');
