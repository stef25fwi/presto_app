import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_audit_log_model.dart';
import 'admin_messaging_service.dart';

class AdminMessagingAuditService {
  final FirebaseFirestore _firestore;

  AdminMessagingAuditService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<AdminAuditLogModel>> watchLogs({int limit = 80}) {
    return _firestore
        .collection('messaging_admin_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminAuditLogModel.fromDocument)
              .toList(growable: false),
        );
  }

  Future<AdminPagedResult<AdminAuditLogModel>> fetchLogsPage({
    int pageSize = 40,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? riskLevel,
    String? action,
  }) async {
    Query<Map<String, dynamic>> query =
        _firestore.collection('messaging_admin_logs');
    final normalizedRisk = riskLevel?.trim();
    final normalizedAction = action?.trim();
    if (normalizedRisk != null && normalizedRisk.isNotEmpty) {
      query = query.where('riskLevel', isEqualTo: normalizedRisk);
    }
    if (normalizedAction != null && normalizedAction.isNotEmpty) {
      query = query.where('action', isEqualTo: normalizedAction);
    }
    query = query.orderBy('createdAt', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.limit(pageSize).get();
    return AdminPagedResult<AdminAuditLogModel>(
      items: snapshot.docs
          .map(AdminAuditLogModel.fromDocument)
          .toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  Future<void> logAction({
    required String action,
    required String targetType,
    required String targetId,
    String reason = '',
    String riskLevel = 'normal',
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    await _firestore.collection('messaging_admin_logs').add({
      'adminId': user?.uid ?? '',
      'adminEmail': user?.email ?? '',
      'adminRole': 'admin',
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'riskLevel': riskLevel,
      'before': before,
      'after': after,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
