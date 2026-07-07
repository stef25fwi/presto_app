import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_notification_log_model.dart';
import 'admin_messaging_service.dart';

class AdminNotificationMonitorService {
  final FirebaseFirestore _firestore;

  AdminNotificationMonitorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<AdminNotificationLogModel>> watchMessagingNotifications({
    int limit = 120,
  }) {
    return _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminNotificationLogModel.fromDocument)
              .where((entry) => entry.isMessagingRelated)
              .toList(growable: false),
        );
  }

  Future<AdminPagedResult<AdminNotificationLogModel>> fetchNotificationsPage({
    int pageSize = 40,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? deliveryStatus,
  }) async {
    final items = <AdminNotificationLogModel>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
    var hasMore = false;

    while (items.length < pageSize) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('notifications')
          .orderBy('createdAt', descending: true);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      final snapshot = await query.limit(pageSize).get();
      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }
      cursor = snapshot.docs.last;
      for (final doc in snapshot.docs) {
        final model = AdminNotificationLogModel.fromDocument(doc);
        if (!model.isMessagingRelated) continue;
        if (deliveryStatus != null &&
            deliveryStatus.trim().isNotEmpty &&
            model.deliveryStatus.trim().toLowerCase() !=
                deliveryStatus.trim().toLowerCase()) {
          continue;
        }
        items.add(model);
        if (items.length >= pageSize) break;
      }
      hasMore = snapshot.docs.length == pageSize;
      if (snapshot.docs.length < pageSize) break;
    }

    return AdminPagedResult<AdminNotificationLogModel>(
      items: items,
      lastDocument: cursor,
      hasMore: hasMore,
    );
  }
}
