import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_metrics_service.dart';

void main() {
  test('construit le service de métriques avec Firestore injecté', () async {
    final service = AdminMessagingMetricsService(
      firestore: FakeFirebaseFirestore(),
    );

    expect(await service.watchCurrentMetrics().first, isNull);
  });
}
