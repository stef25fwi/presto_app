import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/admin/messaging/services/admin_messaging_service.dart';
let source = await readFile(path, 'utf8');

const importLine = "import '../admin_messaging_pagination_policy.dart';";
const importAnchor = "import '../models/admin_attachment_model.dart';";
if (!source.includes(importLine)) {
  if (!source.includes(importAnchor)) {
    throw new Error('admin messaging pagination import anchor not found');
  }
  source = source.replace(importAnchor, `${importLine}\n${importAnchor}`);
}

const fieldAnchor = '  final FirebaseFirestore _firestore;\n';
const fieldReplacement = `${fieldAnchor}\n  static const AdminMessagingPaginationPolicy _paginationPolicy =\n      AdminMessagingPaginationPolicy();\n`;
if (!source.includes('_paginationPolicy =')) {
  if (!source.includes(fieldAnchor)) {
    throw new Error('admin messaging firestore field not found');
  }
  source = source.replace(fieldAnchor, fieldReplacement);
}

const specs = [
  ['AdminConversationModel', 'AdminConversationModel.fromDocument'],
  ['AdminMessageReportModel', 'AdminMessageReportModel.fromDocument'],
  ['AdminMessagingUserModel', 'AdminMessagingUserModel.fromDocument'],
  ['AdminAttachmentModel', 'AdminAttachmentModel.fromDocument'],
];

for (const [model, mapper] of specs) {
  const before = `    final snapshot = await query.limit(pageSize).get();
    return AdminPagedResult<${model}>(
      items: snapshot.docs
          .map(${mapper})
          .toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );`;
  const after = `    final normalizedPageSize = _paginationPolicy.normalizePageSize(pageSize);
    final snapshot = await query
        .limit(_paginationPolicy.queryLimit(normalizedPageSize))
        .get();
    final visibleDocs = _paginationPolicy.visibleItems<
      DocumentSnapshot<Map<String, dynamic>>
    >(
      snapshot.docs,
      requestedPageSize: normalizedPageSize,
    );
    return AdminPagedResult<${model}>(
      items: visibleDocs.map(${mapper}).toList(growable: false),
      lastDocument: visibleDocs.isEmpty ? startAfter : visibleDocs.last,
      hasMore: _paginationPolicy.hasMore(
        receivedCount: snapshot.docs.length,
        requestedPageSize: normalizedPageSize,
      ),
    );`;

  if (!source.includes(after)) {
    if (!source.includes(before)) {
      throw new Error(`pagination block not found for ${model}`);
    }
    source = source.replace(before, after);
  }
}

await writeFile(path, source, 'utf8');
console.log('admin messaging pagination wired');
