import 'package:cloud_firestore/cloud_firestore.dart';

enum AgentAuthorizationStatus { pending, approved, rejected, expired }

enum AgentAuthorizationRisk { low, medium, high, critical }

class AgentAuthorizationRequest {
  final String id;
  final String agentId;
  final String agentLabel;
  final String actionType;
  final String title;
  final String summary;
  final String reason;
  final AgentAuthorizationRisk risk;
  final AgentAuthorizationStatus status;
  final List<String> affectedResources;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? decisionComment;

  const AgentAuthorizationRequest({
    required this.id,
    required this.agentId,
    required this.agentLabel,
    required this.actionType,
    required this.title,
    required this.summary,
    required this.reason,
    required this.risk,
    required this.status,
    required this.affectedResources,
    required this.payload,
    required this.createdAt,
    this.expiresAt,
    this.decidedAt,
    this.decidedBy,
    this.decisionComment,
  });

  bool get isPending => status == AgentAuthorizationStatus.pending;

  factory AgentAuthorizationRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return AgentAuthorizationRequest(
      id: document.id,
      agentId: data['agentId'] as String? ?? 'unknown-agent',
      agentLabel: data['agentLabel'] as String? ?? 'Agent',
      actionType: data['actionType'] as String? ?? 'unknown',
      title: data['title'] as String? ?? 'Demande d’autorisation',
      summary: data['summary'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      risk: AgentAuthorizationRisk.values.firstWhere(
        (value) => value.name == data['risk'],
        orElse: () => AgentAuthorizationRisk.medium,
      ),
      status: AgentAuthorizationStatus.values.firstWhere(
        (value) => value.name == data['status'],
        orElse: () => AgentAuthorizationStatus.pending,
      ),
      affectedResources: (data['affectedResources'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      payload: Map<String, dynamic>.from(
        data['payload'] as Map<dynamic, dynamic>? ?? const {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
      decidedBy: data['decidedBy'] as String?,
      decisionComment: data['decisionComment'] as String?,
    );
  }
}