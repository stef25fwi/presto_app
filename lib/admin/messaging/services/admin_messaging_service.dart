import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_attachment_model.dart';
import '../models/admin_conversation_model.dart';
import '../models/admin_message_report_model.dart';
import '../models/admin_messaging_user_model.dart';

class AdminPagedResult<T> {
  final List<T> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const AdminPagedResult({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}

class AdminMessagingService {
  final FirebaseFirestore _firestore;

  AdminMessagingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<AdminConversationModel>> watchConversations({
    int limit = 120,
    String? status,
    String? region,
    bool? watchlisted,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('conversations');
    final normalizedStatus = status?.trim();
    final normalizedRegion = region?.trim();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      query = query.where('status', isEqualTo: normalizedStatus);
    }
    if (normalizedRegion != null && normalizedRegion.isNotEmpty) {
      query = query.where('region', isEqualTo: normalizedRegion);
    }
    if (watchlisted == true) {
      query = query.where('adminWatchlisted', isEqualTo: true);
    }
    return query
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminConversationModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<AdminPagedResult<AdminConversationModel>> fetchConversationsPage({
    int pageSize = 40,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? status,
    String? region,
    bool? watchlisted,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('conversations');
    final normalizedStatus = status?.trim();
    final normalizedRegion = region?.trim();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      query = query.where('status', isEqualTo: normalizedStatus);
    }
    if (normalizedRegion != null && normalizedRegion.isNotEmpty) {
      query = query.where('region', isEqualTo: normalizedRegion);
    }
    if (watchlisted == true) {
      query = query.where('adminWatchlisted', isEqualTo: true);
    }
    query = query.orderBy('updatedAt', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.limit(pageSize).get();
    return AdminPagedResult<AdminConversationModel>(
      items: snapshot.docs
          .map(AdminConversationModel.fromDocument)
          .toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  Stream<List<AdminMessageReportModel>> watchReports({
    int limit = 120,
    String? status,
    String? priority,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('message_reports');
    final normalizedStatus = status?.trim();
    final normalizedPriority = priority?.trim();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      query = query.where('status', isEqualTo: normalizedStatus);
    }
    if (normalizedPriority != null && normalizedPriority.isNotEmpty) {
      query = query.where('priority', isEqualTo: normalizedPriority);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminMessageReportModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<AdminPagedResult<AdminMessageReportModel>> fetchReportsPage({
    int pageSize = 40,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? status,
    String? priority,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('message_reports');
    final normalizedStatus = status?.trim();
    final normalizedPriority = priority?.trim();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      query = query.where('status', isEqualTo: normalizedStatus);
    }
    if (normalizedPriority != null && normalizedPriority.isNotEmpty) {
      query = query.where('priority', isEqualTo: normalizedPriority);
    }
    query = query.orderBy('createdAt', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.limit(pageSize).get();
    return AdminPagedResult<AdminMessageReportModel>(
      items: snapshot.docs
          .map(AdminMessageReportModel.fromDocument)
          .toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  Stream<List<AdminMessagingUserModel>> watchUsers({
    int limit = 120,
    String? messagingStatus,
    String? role,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('users');
    final normalizedStatus = messagingStatus?.trim();
    final normalizedRole = role?.trim();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      query = query.where('messagingStatus', isEqualTo: normalizedStatus);
    }
    if (normalizedRole != null && normalizedRole.isNotEmpty) {
      query = query.where('primaryRole', isEqualTo: normalizedRole);
    }
    return query
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminMessagingUserModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<AdminPagedResult<AdminMessagingUserModel>> fetchUsersPage({
    int pageSize = 40,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? messagingStatus,
    String? role,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('users');
    final normalizedStatus = messagingStatus?.trim();
    final normalizedRole = role?.trim();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      query = query.where('messagingStatus', isEqualTo: normalizedStatus);
    }
    if (normalizedRole != null && normalizedRole.isNotEmpty) {
      query = query.where('primaryRole', isEqualTo: normalizedRole);
    }
    query = query.orderBy('updatedAt', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.limit(pageSize).get();
    return AdminPagedResult<AdminMessagingUserModel>(
      items: snapshot.docs
          .map(AdminMessagingUserModel.fromDocument)
          .toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  Stream<List<AdminAttachmentModel>> watchAttachments({int limit = 120}) {
    return _firestore
        .collection('message_attachments')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminAttachmentModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<AdminPagedResult<AdminAttachmentModel>> fetchAttachmentsPage({
    int pageSize = 40,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? moderationStatus,
    String? fileType,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('message_attachments');
    final normalizedStatus = moderationStatus?.trim();
    final normalizedFileType = fileType?.trim();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      query = query.where('moderationStatus', isEqualTo: normalizedStatus);
    }
    if (normalizedFileType != null && normalizedFileType.isNotEmpty) {
      query = query.where('fileType', isEqualTo: normalizedFileType);
    }
    query = query.orderBy('createdAt', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.limit(pageSize).get();
    return AdminPagedResult<AdminAttachmentModel>(
      items: snapshot.docs
          .map(AdminAttachmentModel.fromDocument)
          .toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );
  }
}
