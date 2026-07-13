import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_messaging_analytics_service.dart';

class AdminMessagingMetricsService {
  final FirebaseFirestore _firestore;

  AdminMessagingMetricsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<AdminMessagingAnalyticsSnapshot?> watchCurrentMetrics() {
    return _firestore
        .collection('system_settings')
        .doc('messaging_dashboard_current')
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data == null || data.isEmpty) return null;
      return AdminMessagingAnalyticsSnapshot.fromMap(data);
    });
  }
}
