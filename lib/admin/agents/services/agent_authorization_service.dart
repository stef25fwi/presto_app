import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/agent_authorization_request.dart';

class AgentAuthorizationService {
  final FirebaseFirestore firestore;

  AgentAuthorizationService({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      firestore.collection('agent_authorization_requests');

  Stream<List<AgentAuthorizationRequest>> watchPendingRequests() {
    return _requests
        .where('status', isEqualTo: AgentAuthorizationStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AgentAuthorizationRequest.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<int> watchPendingCount() {
    return watchPendingRequests().map((requests) => requests.length);
  }

  Future<String> requestAuthorization({
    required String agentId,
    required String agentLabel,
    required String actionType,
    required String title,
    required String summary,
    required String reason,
    required AgentAuthorizationRisk risk,
    required List<String> affectedResources,
    required Map<String, dynamic> payload,
    Duration validity = const Duration(hours: 24),
  }) async {
    final now = DateTime.now().toUtc();
    final reference = await _requests.add({
      'agentId': agentId,
      'agentLabel': agentLabel,
      'actionType': actionType,
      'title': title,
      'summary': summary,
      'reason': reason,
      'risk': risk.name,
      'status': AgentAuthorizationStatus.pending.name,
      'affectedResources': affectedResources,
      'payload': payload,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(validity)),
      'decidedAt': null,
      'decidedBy': null,
      'decisionComment': null,
    });
    return reference.id;
  }

  Future<void> approve({
    required String requestId,
    required String superAdminUid,
    required String comment,
  }) {
    return _decide(
      requestId: requestId,
      superAdminUid: superAdminUid,
      status: AgentAuthorizationStatus.approved,
      comment: comment,
    );
  }

  Future<void> reject({
    required String requestId,
    required String superAdminUid,
    required String comment,
  }) {
    return _decide(
      requestId: requestId,
      superAdminUid: superAdminUid,
      status: AgentAuthorizationStatus.rejected,
      comment: comment,
    );
  }

  Future<void> _decide({
    required String requestId,
    required String superAdminUid,
    required AgentAuthorizationStatus status,
    required String comment,
  }) async {
    final reference = _requests.doc(requestId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('La demande d’autorisation n’existe plus.');
      }
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] != AgentAuthorizationStatus.pending.name) {
        throw StateError('Cette demande a déjà été traitée.');
      }
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
        transaction.update(reference, {
          'status': AgentAuthorizationStatus.expired.name,
          'decidedAt': FieldValue.serverTimestamp(),
        });
        throw StateError('Cette demande d’autorisation a expiré.');
      }
      transaction.update(reference, {
        'status': status.name,
        'decidedAt': FieldValue.serverTimestamp(),
        'decidedBy': superAdminUid,
        'decisionComment': comment.trim(),
      });
    });
  }
}