import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_messaging_audit_service.dart';

class AdminModerationService {
  final FirebaseFirestore _firestore;
  final AdminMessagingAuditService _auditService;

  AdminModerationService({
    FirebaseFirestore? firestore,
    AdminMessagingAuditService? auditService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auditService = auditService ?? AdminMessagingAuditService();

  Future<void> updateConversationStatus({
    required String conversationId,
    required String status,
    String reason = '',
  }) async {
    await _firestore.collection('conversations').doc(conversationId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auditService.logAction(
      action: 'update_conversation_status',
      targetType: 'conversation',
      targetId: conversationId,
      reason: reason,
      riskLevel: 'medium',
      after: {'status': status},
    );
  }

  Future<void> markConversationWatchlisted({
    required String conversationId,
    required bool watchlisted,
    String reason = '',
  }) async {
    await _firestore.collection('conversations').doc(conversationId).set({
      'adminWatchlisted': watchlisted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auditService.logAction(
      action: watchlisted
          ? 'watchlist_conversation'
          : 'unwatchlist_conversation',
      targetType: 'conversation',
      targetId: conversationId,
      reason: reason,
      riskLevel: 'medium',
      after: {'adminWatchlisted': watchlisted},
    );
  }

  Future<void> updateUserMessagingStatus({
    required String userId,
    required String status,
    String reason = '',
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'messagingStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auditService.logAction(
      action: 'update_user_messaging_status',
      targetType: 'user',
      targetId: userId,
      reason: reason,
      riskLevel: 'high',
      after: {'messagingStatus': status},
    );
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String decision = '',
    String reason = '',
  }) async {
    await _firestore.collection('message_reports').doc(reportId).set({
      'status': status,
      if (decision.trim().isNotEmpty) 'adminDecision': decision,
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auditService.logAction(
      action: 'update_message_report_status',
      targetType: 'message_report',
      targetId: reportId,
      reason: reason,
      riskLevel: 'high',
      after: {
        'status': status,
        if (decision.trim().isNotEmpty) 'adminDecision': decision,
      },
    );
  }

  Future<void> updateAttachmentModerationStatus({
    required String attachmentId,
    required String status,
    String reason = '',
  }) async {
    await _firestore.collection('message_attachments').doc(attachmentId).set({
      'moderationStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'deleted') 'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auditService.logAction(
      action: 'update_attachment_moderation_status',
      targetType: 'message_attachment',
      targetId: attachmentId,
      reason: reason,
      riskLevel: 'high',
      after: {'moderationStatus': status},
    );
  }
}