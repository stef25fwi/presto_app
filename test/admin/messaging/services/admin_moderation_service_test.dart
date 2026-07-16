import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_audit_service.dart';
import 'package:presto_app/admin/messaging/services/admin_moderation_service.dart';

class _AuditCall {
  const _AuditCall({
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.riskLevel,
    required this.before,
    required this.after,
  });

  final String action;
  final String targetType;
  final String targetId;
  final String reason;
  final String riskLevel;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
}

class _AuditSpy extends AdminMessagingAuditService {
  _AuditSpy() : super(firestore: FakeFirebaseFirestore());

  final calls = <_AuditCall>[];

  @override
  Future<void> logAction({
    required String action,
    required String targetType,
    required String targetId,
    String reason = '',
    String riskLevel = 'normal',
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    calls.add(
      _AuditCall(
        action: action,
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        riskLevel: riskLevel,
        before: before,
        after: after,
      ),
    );
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _AuditSpy audit;
  late AdminModerationService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    audit = _AuditSpy();
    service = AdminModerationService(
      firestore: firestore,
      auditService: audit,
    );
  });

  test('updateConversationStatus fusionne le statut et trace l’action', () async {
    await firestore.collection('conversations').doc('conversation-1').set({
      'existing': true,
    });

    await service.updateConversationStatus(
      conversationId: 'conversation-1',
      status: 'suspendue',
      reason: 'Signalements répétés',
    );

    final data = (await firestore
            .collection('conversations')
            .doc('conversation-1')
            .get())
        .data()!;
    expect(data['existing'], isTrue);
    expect(data['status'], 'suspendue');
    expect(data['updatedAt'], isA<Timestamp>());

    expect(audit.calls, hasLength(1));
    final call = audit.calls.single;
    expect(call.action, 'update_conversation_status');
    expect(call.targetType, 'conversation');
    expect(call.targetId, 'conversation-1');
    expect(call.reason, 'Signalements répétés');
    expect(call.riskLevel, 'medium');
    expect(call.after, {'status': 'suspendue'});
  });

  for (final watchlisted in <bool>[true, false]) {
    test('markConversationWatchlisted couvre watchlisted=$watchlisted', () async {
      await service.markConversationWatchlisted(
        conversationId: 'conversation-$watchlisted',
        watchlisted: watchlisted,
        reason: 'Contrôle admin',
      );

      final data = (await firestore
              .collection('conversations')
              .doc('conversation-$watchlisted')
              .get())
          .data()!;
      expect(data['adminWatchlisted'], watchlisted);
      expect(data['updatedAt'], isA<Timestamp>());

      final call = audit.calls.single;
      expect(
        call.action,
        watchlisted ? 'watchlist_conversation' : 'unwatchlist_conversation',
      );
      expect(call.targetType, 'conversation');
      expect(call.targetId, 'conversation-$watchlisted');
      expect(call.reason, 'Contrôle admin');
      expect(call.riskLevel, 'medium');
      expect(call.after, {'adminWatchlisted': watchlisted});
    });
  }

  test('updateUserMessagingStatus écrit le statut et un audit à risque élevé',
      () async {
    await service.updateUserMessagingStatus(
      userId: 'user-1',
      status: 'bloqué',
      reason: 'Harcèlement confirmé',
    );

    final data =
        (await firestore.collection('users').doc('user-1').get()).data()!;
    expect(data['messagingStatus'], 'bloqué');
    expect(data['updatedAt'], isA<Timestamp>());

    final call = audit.calls.single;
    expect(call.action, 'update_user_messaging_status');
    expect(call.targetType, 'user');
    expect(call.targetId, 'user-1');
    expect(call.reason, 'Harcèlement confirmé');
    expect(call.riskLevel, 'high');
    expect(call.after, {'messagingStatus': 'bloqué'});
  });

  test('updateReportStatus inclut une décision non vide', () async {
    await service.updateReportStatus(
      reportId: 'report-with-decision',
      status: 'résolu',
      decision: ' action_taken ',
      reason: 'Décision validée',
    );

    final data = (await firestore
            .collection('message_reports')
            .doc('report-with-decision')
            .get())
        .data()!;
    expect(data['status'], 'résolu');
    expect(data['adminDecision'], ' action_taken ');
    expect(data['resolvedAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());

    final call = audit.calls.single;
    expect(call.action, 'update_message_report_status');
    expect(call.targetType, 'message_report');
    expect(call.targetId, 'report-with-decision');
    expect(call.reason, 'Décision validée');
    expect(call.riskLevel, 'high');
    expect(call.after, {
      'status': 'résolu',
      'adminDecision': ' action_taken ',
    });
  });

  test('updateReportStatus omet une décision vide', () async {
    await service.updateReportStatus(
      reportId: 'report-without-decision',
      status: 'en revue',
      decision: '   ',
    );

    final data = (await firestore
            .collection('message_reports')
            .doc('report-without-decision')
            .get())
        .data()!;
    expect(data['status'], 'en revue');
    expect(data.containsKey('adminDecision'), isFalse);

    final call = audit.calls.single;
    expect(call.reason, isEmpty);
    expect(call.after, {'status': 'en revue'});
  });

  test('updateAttachmentModerationStatus ajoute deletedAt pour deleted',
      () async {
    await service.updateAttachmentModerationStatus(
      attachmentId: 'attachment-deleted',
      status: 'deleted',
      reason: 'Fichier interdit',
    );

    final data = (await firestore
            .collection('message_attachments')
            .doc('attachment-deleted')
            .get())
        .data()!;
    expect(data['moderationStatus'], 'deleted');
    expect(data['updatedAt'], isA<Timestamp>());
    expect(data['deletedAt'], isA<Timestamp>());

    final call = audit.calls.single;
    expect(call.action, 'update_attachment_moderation_status');
    expect(call.targetType, 'message_attachment');
    expect(call.targetId, 'attachment-deleted');
    expect(call.reason, 'Fichier interdit');
    expect(call.riskLevel, 'high');
    expect(call.after, {'moderationStatus': 'deleted'});
  });

  test('updateAttachmentModerationStatus omet deletedAt pour approved',
      () async {
    await service.updateAttachmentModerationStatus(
      attachmentId: 'attachment-approved',
      status: 'approved',
    );

    final data = (await firestore
            .collection('message_attachments')
            .doc('attachment-approved')
            .get())
        .data()!;
    expect(data['moderationStatus'], 'approved');
    expect(data.containsKey('deletedAt'), isFalse);

    final call = audit.calls.single;
    expect(call.reason, isEmpty);
    expect(call.after, {'moderationStatus': 'approved'});
  });
}
