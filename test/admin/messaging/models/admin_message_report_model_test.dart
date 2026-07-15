import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/models/admin_message_report_model.dart';

void main() {
  test('fromData parse toutes les valeurs du signalement', () {
    final createdAt = Timestamp.fromDate(DateTime.utc(2026, 7, 15, 10));
    final model = AdminMessageReportModel.fromData(
      id: 'report-1',
      data: <String, dynamic>{
        'conversationId': 'conversation-1',
        'messageId': 'message-1',
        'reportedBy': 'user-a',
        'reportedUserId': 'user-b',
        'reason': 'harcelement',
        'description': 'Description',
        'priority': 'haute',
        'status': 'en_cours',
        'assignedTo': 'admin-1',
        'adminDecision': 'masquer',
        'createdAt': createdAt,
        'resolvedAt': '2026-07-15T11:00:00.000Z',
      },
    );

    expect(model.id, 'report-1');
    expect(model.conversationId, 'conversation-1');
    expect(model.messageId, 'message-1');
    expect(model.reportedBy, 'user-a');
    expect(model.reportedUserId, 'user-b');
    expect(model.reason, 'harcelement');
    expect(model.description, 'Description');
    expect(model.priority, 'haute');
    expect(model.status, 'en_cours');
    expect(model.assignedTo, 'admin-1');
    expect(model.adminDecision, 'masquer');
    expect(model.createdAt, createdAt.toDate());
    expect(model.resolvedAt, DateTime.parse('2026-07-15T11:00:00.000Z'));
  });

  test('fromData applique les valeurs par défaut et normalise les types', () {
    final model = AdminMessageReportModel.fromData(
      id: 'report-2',
      data: <String, dynamic>{
        'conversationId': 42,
        'messageId': null,
        'reportedBy': true,
        'createdAt': -1,
        'resolvedAt': <String, dynamic>{'invalid': true},
      },
    );

    expect(model.conversationId, '42');
    expect(model.messageId, '');
    expect(model.reportedBy, 'true');
    expect(model.reportedUserId, '');
    expect(model.reason, 'autre');
    expect(model.description, '');
    expect(model.priority, 'moyenne');
    expect(model.status, 'nouveau');
    expect(model.assignedTo, '');
    expect(model.adminDecision, '');
    expect(model.createdAt, isNull);
    expect(model.resolvedAt, isNull);
  });
}
