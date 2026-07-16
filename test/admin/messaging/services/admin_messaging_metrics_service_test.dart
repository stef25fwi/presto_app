import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_metrics_service.dart';

void main() {
  test('retourne null quand le document de métriques est absent', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminMessagingMetricsService(firestore: firestore);

    final metrics = await service.watchCurrentMetrics().first;

    expect(metrics, isNull);
  });

  test('retourne null quand le document de métriques est vide', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('system_settings')
        .doc('messaging_dashboard_current')
        .set(<String, dynamic>{});
    final service = AdminMessagingMetricsService(firestore: firestore);

    final metrics = await service.watchCurrentMetrics().first;

    expect(metrics, isNull);
  });

  test('transforme le document courant en snapshot analytique', () async {
    final firestore = FakeFirebaseFirestore();
    final generatedAt = DateTime.utc(2026, 7, 16, 12);
    await firestore
        .collection('system_settings')
        .doc('messaging_dashboard_current')
        .set(<String, dynamic>{
      'totalConversations': 120,
      'activeToday': 18,
      'totalMessages': 480,
      'unansweredConversations': 7,
      'reportedConversations': 5,
      'blockedUsers': 3,
      'attachmentsCount': 62,
      'storageBytes': 4096,
      'activeUsers': 44,
      'watchlistedConversations': 4,
      'criticalRiskConversations': 2,
      'pendingReports': 3,
      'resolvedReports': 9,
      'averageResponseHours': 1.75,
      'providerResponseRate': 82.5,
      'pushSentCount': 100,
      'pushDeliveredCount': 93,
      'pushFailedCount': 7,
      'generatedAt': generatedAt.toIso8601String(),
      'source': 'scheduled',
      'windowHours': '24',
      'sampledNotifications': 100,
    });
    final service = AdminMessagingMetricsService(firestore: firestore);

    final metrics = await service.watchCurrentMetrics().first;

    expect(metrics, isNotNull);
    expect(metrics!.totalConversations, 120);
    expect(metrics.activeToday, 18);
    expect(metrics.totalMessages, 480);
    expect(metrics.unansweredConversations, 7);
    expect(metrics.reportedConversations, 5);
    expect(metrics.blockedUsers, 3);
    expect(metrics.attachmentsCount, 62);
    expect(metrics.storageBytes, 4096);
    expect(metrics.activeUsers, 44);
    expect(metrics.watchlistedConversations, 4);
    expect(metrics.criticalRiskConversations, 2);
    expect(metrics.pendingReports, 3);
    expect(metrics.resolvedReports, 9);
    expect(metrics.averageResponseHours, 1.75);
    expect(metrics.providerResponseRate, 82.5);
    expect(metrics.pushSentCount, 100);
    expect(metrics.pushDeliveredCount, 93);
    expect(metrics.pushFailedCount, 7);
    expect(metrics.generatedAt, generatedAt);
    expect(metrics.source, 'scheduled');
    expect(metrics.windowHours, 24);
    expect(metrics.sampledNotifications, 100);
  });

  test('le flux reflète les mises à jour successives du document', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminMessagingMetricsService(firestore: firestore);
    final values = <int?>[];
    final subscription = service.watchCurrentMetrics().listen(
          (metrics) => values.add(metrics?.totalConversations),
        );
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    await firestore
        .collection('system_settings')
        .doc('messaging_dashboard_current')
        .set(<String, dynamic>{'totalConversations': 8});
    await pumpEventQueue();

    expect(values, containsAllInOrder(<int?>[null, 8]));
  });
}
