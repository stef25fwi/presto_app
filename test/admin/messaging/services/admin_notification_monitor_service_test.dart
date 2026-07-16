import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/services/admin_notification_monitor_service.dart';

Future<void> _addNotification(
  FakeFirebaseFirestore firestore, {
  required String id,
  required int createdAt,
  String conversationId = '',
  String routeName = '',
  String deliveryStatus = 'unknown',
}) {
  return firestore.collection('notifications').doc(id).set(
    <String, Object?>{
      'userId': 'user-$id',
      'title': 'Title $id',
      'message': 'Message $id',
      'conversationId': conversationId,
      'routeName': routeName,
      'deliveryStatus': deliveryStatus,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(createdAt),
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('utilise Firestore par défaut sans dépendance injectée', () {
    expect(AdminNotificationMonitorService.new, returnsNormally);
  });

  test('observe les notifications de messagerie dans l ordre attendu',
      () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminNotificationMonitorService(firestore: firestore);

    await _addNotification(
      firestore,
      id: 'conversation-new',
      createdAt: 3000,
      conversationId: 'conversation-1',
      deliveryStatus: 'sent',
    );
    await _addNotification(
      firestore,
      id: 'route-middle',
      createdAt: 2000,
      routeName: '/messages/thread-2',
      deliveryStatus: 'failed',
    );
    await _addNotification(
      firestore,
      id: 'unrelated-old',
      createdAt: 1000,
      routeName: '/offers/offer-1',
      deliveryStatus: 'sent',
    );

    final notifications =
        await service.watchMessagingNotifications(limit: 3).first;

    expect(
      notifications.map((notification) => notification.id),
      <String>['conversation-new', 'route-middle'],
    );
    expect(notifications.first.deliveryStatus, 'sent');
    expect(notifications.last.routeName, '/messages/thread-2');
  });

  test('pagine au-delà des entrées hors messagerie et filtre le statut',
      () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminNotificationMonitorService(firestore: firestore);

    await _addNotification(
      firestore,
      id: 'unrelated-new',
      createdAt: 5000,
      routeName: '/home',
    );
    await _addNotification(
      firestore,
      id: 'sent-new',
      createdAt: 4000,
      conversationId: 'conversation-4',
      deliveryStatus: 'sent',
    );
    await _addNotification(
      firestore,
      id: 'failed-middle',
      createdAt: 3000,
      routeName: '/messages/thread-3',
      deliveryStatus: 'failed',
    );
    await _addNotification(
      firestore,
      id: 'unrelated-middle',
      createdAt: 2000,
      routeName: '/account',
      deliveryStatus: 'sent',
    );
    await _addNotification(
      firestore,
      id: 'sent-old',
      createdAt: 1000,
      conversationId: 'conversation-1',
      deliveryStatus: 'SENT',
    );

    final page = await service.fetchNotificationsPage(
      pageSize: 2,
      deliveryStatus: ' sent ',
    );

    expect(
      page.items.map((notification) => notification.id),
      <String>['sent-new', 'sent-old'],
    );
    expect(page.lastDocument?.id, 'sent-old');
    expect(page.hasMore, isFalse);
  });

  test('reprend après le curseur et signale une page suivante', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminNotificationMonitorService(firestore: firestore);

    for (var index = 4; index >= 1; index -= 1) {
      await _addNotification(
        firestore,
        id: 'message-$index',
        createdAt: index * 1000,
        conversationId: 'conversation-$index',
        deliveryStatus: 'sent',
      );
    }

    final firstSnapshot = await firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    final page = await service.fetchNotificationsPage(
      pageSize: 2,
      startAfter: firstSnapshot.docs.single,
    );

    expect(
      page.items.map((notification) => notification.id),
      <String>['message-3', 'message-2'],
    );
    expect(page.lastDocument?.id, 'message-2');
    expect(page.hasMore, isTrue);
  });

  test('retourne une page vide en fin de collection', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminNotificationMonitorService(firestore: firestore);

    final page = await service.fetchNotificationsPage(pageSize: 3);

    expect(page.items, isEmpty);
    expect(page.lastDocument, isNull);
    expect(page.hasMore, isFalse);
  });
}
