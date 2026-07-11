import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/admin/messaging/services/admin_messaging_service.dart';
let source = await readFile(path, 'utf8');
const before = '.visibleItems<DocumentSnapshot<Map<String, dynamic>>>';
const after = '.visibleItems<QueryDocumentSnapshot<Map<String, dynamic>>>';
const matches = source.split(before).length - 1;
if (matches !== 4) {
  throw new Error(`expected 4 pagination type occurrences, found ${matches}`);
}
source = source.split(before).join(after);
await writeFile(path, source, 'utf8');
console.log('admin messaging pagination snapshot types fixed');
