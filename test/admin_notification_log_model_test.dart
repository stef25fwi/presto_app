import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_notification_log_model.dart';

void main() {
  test('fromData parses complete notification log data', () {
    final createdAt = DateTime.utc(2026, 7, 15, 10, 30);

    final model = AdminNotificationLogModel.fromData(
      id: 'notification-1',
      data: <String, dynamic>{
        'userId': 'user-1',
        'title': 'Nouveau message',
        'message': 'Alice vous a écrit',
        'routeName': '/messages/thread-1',
        'conversationId': 'thread-1',
        'type': 'message',
        'deliveryStatus': 'delivered',
        'createdAt': createdAt,
      },
    );

    expect(model.id, 'notification-1');
    expect(model.userId, 'user-1');
    expect(model.title, 'Nouveau message');
    expect(model.body, 'Alice vous a écrit');
    expect(model.routeName, '/messages/thread-1');
    expect(model.conversationId, 'thread-1');
    expect(model.type, 'message');
    expect(model.deliveryStatus, 'delivered');
    expect(model.createdAt, createdAt);
    expect(model.isMessagingRelated, isTrue);
  });

  test('fromData applies legacy aliases and defaults', () {
    final model = AdminNotificationLogModel.fromData(
      id: 'notification-2',
      data: const <String, dynamic>{
        'body': 'Contenu historique',
        'status': 'failed',
      },
    );

    expect(model.userId, '');
    expect(model.title, '');
    expect(model.body, 'Contenu historique');
    expect(model.routeName, '');
    expect(model.conversationId, '');
    expect(model.type, 'notification');
    expect(model.deliveryStatus, 'failed');
    expect(model.createdAt, isNull);
    expect(model.isMessagingRelated, isFalse);
  });

  test('messaging relation detects route and trims conversation id', () {
    final routeModel = AdminNotificationLogModel.fromData(
      id: 'notification-3',
      data: const <String, dynamic>{'routeName': '/messages'},
    );
    final blankConversationModel = AdminNotificationLogModel.fromData(
      id: 'notification-4',
      data: const <String, dynamic>{'conversationId': '   '},
    );

    expect(routeModel.isMessagingRelated, isTrue);
    expect(blankConversationModel.isMessagingRelated, isFalse);
  });
}
