import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/agents/models/agent_authorization_request.dart';

void main() {
  test('parses a complete authorization request document', () async {
    final firestore = FakeFirebaseFirestore();
    final createdAt = Timestamp.fromMillisecondsSinceEpoch(1000);
    final expiresAt = Timestamp.fromMillisecondsSinceEpoch(2000);
    final decidedAt = Timestamp.fromMillisecondsSinceEpoch(3000);

    await firestore.collection('requests').doc('request-1').set(
      <String, dynamic>{
        'agentId': 'agent-7',
        'agentLabel': 'Agent terrain',
        'actionType': 'delete-user',
        'title': 'Suppression sensible',
        'summary': 'Supprimer un compte',
        'reason': 'Demande explicite',
        'risk': AgentAuthorizationRisk.critical.name,
        'status': AgentAuthorizationStatus.approved.name,
        'affectedResources': <dynamic>['users/u1', 42, 'logs/l1'],
        'payload': <String, dynamic>{'userId': 'u1', 'confirmed': true},
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'decidedAt': decidedAt,
        'decidedBy': 'superadmin',
        'decisionComment': 'Validé',
      },
    );

    final document = await firestore.collection('requests').doc('request-1').get();
    final request = AgentAuthorizationRequest.fromDocument(document);

    expect(request.id, 'request-1');
    expect(request.agentId, 'agent-7');
    expect(request.agentLabel, 'Agent terrain');
    expect(request.actionType, 'delete-user');
    expect(request.title, 'Suppression sensible');
    expect(request.summary, 'Supprimer un compte');
    expect(request.reason, 'Demande explicite');
    expect(request.risk, AgentAuthorizationRisk.critical);
    expect(request.status, AgentAuthorizationStatus.approved);
    expect(request.isPending, isFalse);
    expect(request.affectedResources, <String>['users/u1', 'logs/l1']);
    expect(request.payload, <String, dynamic>{'userId': 'u1', 'confirmed': true});
    expect(request.createdAt, createdAt.toDate());
    expect(request.expiresAt, expiresAt.toDate());
    expect(request.decidedAt, decidedAt.toDate());
    expect(request.decidedBy, 'superadmin');
    expect(request.decisionComment, 'Validé');
  });

  test('uses safe defaults for a missing or malformed document', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('requests').doc('request-empty').set(
      <String, dynamic>{
        'risk': 'unsupported-risk',
        'status': 'unsupported-status',
        'affectedResources': <dynamic>[1, false],
        'payload': <String, dynamic>{},
      },
    );

    final document =
        await firestore.collection('requests').doc('request-empty').get();
    final request = AgentAuthorizationRequest.fromDocument(document);

    expect(request.id, 'request-empty');
    expect(request.agentId, 'unknown-agent');
    expect(request.agentLabel, 'Agent');
    expect(request.actionType, 'unknown');
    expect(request.title, 'Demande d’autorisation');
    expect(request.summary, isEmpty);
    expect(request.reason, isEmpty);
    expect(request.risk, AgentAuthorizationRisk.medium);
    expect(request.status, AgentAuthorizationStatus.pending);
    expect(request.isPending, isTrue);
    expect(request.affectedResources, isEmpty);
    expect(request.payload, isEmpty);
    expect(request.createdAt, isA<DateTime>());
    expect(request.expiresAt, isNull);
    expect(request.decidedAt, isNull);
    expect(request.decidedBy, isNull);
    expect(request.decisionComment, isNull);
  });
}
