#!/usr/bin/env node

import fs from 'node:fs/promises';

const path = 'tools/apply_cursor_pagination.mjs';
let content = await fs.readFile(path, 'utf8');

const oldBlock = `  content = replaceOnce(
    content,
    "  String? categoryId,\\n  String? cityId,\\n}) {",
    "  String? categoryId,\\n  String? cityId,\\n  DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,\\n}) {",
    'query cursor parameter',
  );`;

const newBlock = `  content = replaceOnce(
    content,
    "List<Query<Map<String, dynamic>>> buildMarketplaceListingsBrowseQueries({\\n  FirebaseFirestore? firestore,\\n  int limit = 200,\\n  bool latestFirst = true,\\n  String? categoryId,\\n  String? cityId,\\n}) {",
    "List<Query<Map<String, dynamic>>> buildMarketplaceListingsBrowseQueries({\\n  FirebaseFirestore? firestore,\\n  int limit = 200,\\n  bool latestFirst = true,\\n  String? categoryId,\\n  String? cityId,\\n  DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,\\n}) {",
    'query cursor parameter',
  );`;

if (!content.includes(newBlock)) {
  const count = content.split(oldBlock).length - 1;
  if (count !== 1) {
    throw new Error(`cursor signature patch: expected one source block, found ${count}`);
  }
  content = content.replace(oldBlock, newBlock);
}

await fs.writeFile(path, content, 'utf8');
console.log('cursor query signature patch: OK');
