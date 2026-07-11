import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_listing_record.dart';

class AdminListingsPageResult {
  const AdminListingsPageResult({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });

  final List<AdminListingRecord> items;
  final Object? cursor;
  final bool hasMore;
}

abstract interface class AdminListingsRepository {
  Future<AdminListingsPageResult> fetchPage({
    Object? startAfter,
    int pageSize = 30,
  });
}

class FirestoreAdminListingsRepository implements AdminListingsRepository {
  FirestoreAdminListingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<AdminListingsPageResult> fetchPage({
    Object? startAfter,
    int pageSize = 30,
  }) async {
    final normalizedPageSize = pageSize.clamp(1, 50);
    Query<Map<String, dynamic>> query = _firestore
        .collection('listings')
        .orderBy('createdAt', descending: true)
        .limit(normalizedPageSize + 1);

    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final hasMore = snapshot.docs.length > normalizedPageSize;
    final visibleDocs = snapshot.docs.take(normalizedPageSize).toList();
    final items = visibleDocs
        .map(
          (document) => AdminListingRecord.fromData(
            id: document.id,
            data: document.data(),
          ),
        )
        .where((record) => record.status != 'deleted')
        .toList(growable: false);

    return AdminListingsPageResult(
      items: items,
      cursor: visibleDocs.isEmpty ? startAfter : visibleDocs.last,
      hasMore: hasMore,
    );
  }
}
