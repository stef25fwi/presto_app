import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/agents/models/agent_authorization_request.dart';

void main() {
  test('construit une demande en attente avec ses métadonnées', () {
    final createdAt = DateTime.utc(2026, 7, 24, 12);
    final expiresAt = createdAt.add(const Duration(hours: 1));

    final request = AgentAuthorizationRequest(
      id: 'request-1',
      agentId: 'agent-1',
      agentLabel: 'Agent couverture',
      actionType: 'coverage',
      title: 'Autoriser une mission',
      summary: 'Suit une cible critique',
      reason: 'Maintenir la progression LCOV',
      risk: AgentAuthorizationRisk.low,
      status: AgentAuthorizationStatus.pending,
      affectedResources: const <String>['lib/admin'],
      payload: const <String, dynamic>{'worker': 2},
      createdAt: createdAt,
      expiresAt: expiresAt,
    );

    expect(request.id, 'request-1');
    expect(request.agentId, 'agent-1');
    expect(request.agentLabel, 'Agent couverture');
    expect(request.actionType, 'coverage');
    expect(request.title, 'Autoriser une mission');
    expect(request.summary, 'Suit une cible critique');
    expect(request.reason, 'Maintenir la progression LCOV');
    expect(request.risk, AgentAuthorizationRisk.low);
    expect(request.status, AgentAuthorizationStatus.pending);
    expect(request.isPending, isTrue);
    expect(request.affectedResources, const <String>['lib/admin']);
    expect(request.payload, const <String, dynamic>{'worker': 2});
    expect(request.createdAt, createdAt);
    expect(request.expiresAt, expiresAt);
    expect(request.decidedAt, isNull);
    expect(request.decidedBy, isNull);
    expect(request.decisionComment, isNull);
  });

  test('distingue une demande déjà approuvée', () {
    final request = AgentAuthorizationRequest(
      id: 'request-2',
      agentId: 'agent-2',
      agentLabel: 'Agent secondaire',
      actionType: 'review',
      title: 'Valider une mission',
      summary: '',
      reason: '',
      risk: AgentAuthorizationRisk.critical,
      status: AgentAuthorizationStatus.approved,
      affectedResources: const <String>[],
      payload: const <String, dynamic>{},
      createdAt: DateTime.utc(2026, 7, 24),
      decidedAt: DateTime.utc(2026, 7, 24, 13),
      decidedBy: 'super-admin',
      decisionComment: 'Validée',
    );

    expect(request.isPending, isFalse);
    expect(request.risk, AgentAuthorizationRisk.critical);
    expect(request.decidedBy, 'super-admin');
    expect(request.decisionComment, 'Validée');
  });
}
