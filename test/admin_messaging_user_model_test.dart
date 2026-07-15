import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_messaging_user_model.dart';

void main() {
  test('fromData parses complete messaging user data', () {
    final createdAt = DateTime.utc(2026, 1, 2, 3, 4);
    final lastActivityAt = DateTime.utc(2026, 2, 3, 4, 5);

    final model = AdminMessagingUserModel.fromData(
      uid: 'user-1',
      data: <String, dynamic>{
        'displayName': 'Alice',
        'email': 'alice@example.com',
        'primaryRole': 'pro',
        'region': 'Guadeloupe',
        'createdAt': createdAt,
        'lastMessagingActivityAt': lastActivityAt,
        'messagingOpenConversations': 3.8,
        'messagesSent': 12,
        'messagesReceived': 9.2,
        'messagingReportsReceived': 2,
        'messagingReportsSent': 1.9,
        'messagingStatus': 'surveille',
        'messagingRiskScore': 7.4,
        'messagingResponseRate': 82,
        'averageResponseHours': 1.5,
      },
    );

    expect(model.uid, 'user-1');
    expect(model.name, 'Alice');
    expect(model.email, 'alice@example.com');
    expect(model.role, 'pro');
    expect(model.region, 'Guadeloupe');
    expect(model.createdAt, createdAt);
    expect(model.lastActivityAt, lastActivityAt);
    expect(model.openConversations, 3);
    expect(model.messagesSent, 12);
    expect(model.messagesReceived, 9);
    expect(model.reportsReceived, 2);
    expect(model.reportsSent, 1);
    expect(model.messagingStatus, 'surveille');
    expect(model.riskScore, 7);
    expect(model.responseRate, 82.0);
    expect(model.averageResponseHours, 1.5);
  });

  test('fromData applies aliases and default values', () {
    final updatedAt = DateTime.utc(2026, 3, 4);
    final model = AdminMessagingUserModel.fromData(
      uid: 'user-2',
      data: <String, dynamic>{
        'name': 'Bob',
        'role': 'user',
        'updatedAt': updatedAt,
        'messagingOpenConversations': 'invalid',
        'messagesSent': null,
        'messagesReceived': false,
        'messagingReportsReceived': <String>[],
        'messagingReportsSent': '1',
        'messagingRiskScore': 'high',
        'messagingResponseRate': null,
        'averageResponseHours': 'slow',
      },
    );

    expect(model.name, 'Bob');
    expect(model.email, '');
    expect(model.role, 'user');
    expect(model.region, 'Non renseignée');
    expect(model.createdAt, isNull);
    expect(model.lastActivityAt, updatedAt);
    expect(model.openConversations, 0);
    expect(model.messagesSent, 0);
    expect(model.messagesReceived, 0);
    expect(model.reportsReceived, 0);
    expect(model.reportsSent, 0);
    expect(model.messagingStatus, 'actif');
    expect(model.riskScore, 0);
    expect(model.responseRate, 0.0);
    expect(model.averageResponseHours, 0.0);
  });

  test('fromData falls back through pseudo and lastSeenAt', () {
    final lastSeenAt = DateTime.utc(2026, 4, 5);
    final model = AdminMessagingUserModel.fromData(
      uid: 'user-3',
      data: <String, dynamic>{
        'pseudo': 'Charlie',
        'lastSeenAt': lastSeenAt,
      },
    );

    expect(model.name, 'Charlie');
    expect(model.lastActivityAt, lastSeenAt);
  });

  test('fromData uses final identity defaults when aliases are absent', () {
    final model = AdminMessagingUserModel.fromData(
      uid: 'user-4',
      data: const <String, dynamic>{},
    );

    expect(model.name, 'Utilisateur');
    expect(model.role, 'user');
    expect(model.region, 'Non renseignée');
  });
}
