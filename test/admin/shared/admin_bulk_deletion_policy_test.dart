import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/shared/admin_bulk_deletion_policy.dart';

void main() {
  const policy = AdminBulkDeletionPolicy(maxBatchSize: 2);

  test('normalise, déduplique et conserve l ordre des identifiants', () {
    expect(policy.normalizeIds(<String>[' a ', '', 'b', 'a', ' c ']), <String>[
      'a',
      'b',
      'c',
    ]);
  });

  test('découpe la sélection en lots bornés', () {
    expect(
      policy.buildBatches(<String>['a', 'b', 'c', 'd', 'e']),
      <List<String>>[
        <String>['a', 'b'],
        <String>['c', 'd'],
        <String>['e'],
      ],
    );
  });

  test('exclut immédiatement les données supprimées des statistiques', () {
    expect(
      policy.isActiveForStatistics(<String, Object?>{'status': 'active'}),
      isTrue,
    );
    expect(
      policy.isActiveForStatistics(<String, Object?>{'status': 'deleted'}),
      isFalse,
    );
    expect(
      policy.isActiveForStatistics(<String, Object?>{
        'status': 'active',
        'deletedAt': '2026-07-11T14:00:00Z',
      }),
      isFalse,
    );
  });

  test('produit un snapshot d audit immuable et normalisé', () {
    final audit = policy.buildAuditSnapshot(
      entityType: ' commune ',
      entityId: ' commune-1 ',
      deletedBy: ' admin-1 ',
      deletedAt: DateTime.parse('2026-07-11T10:00:00-04:00'),
      deletionReason: ' doublon ',
      snapshot: <String, Object?>{'name': 'Baie-Mahault'},
    );

    expect(audit['operation'], 'delete');
    expect(audit['status'], 'deleted');
    expect(audit['entityType'], 'commune');
    expect(audit['entityId'], 'commune-1');
    expect(audit['deletedBy'], 'admin-1');
    expect(audit['deletedAt'], '2026-07-11T14:00:00.000Z');
    expect(audit['deletionReason'], 'doublon');
    expect(audit['snapshot'], <String, Object?>{'name': 'Baie-Mahault'});
    expect(() => audit['extra'] = true, throwsUnsupportedError);
  });

  test('refuse un audit sans identité ou acteur', () {
    expect(
      () => policy.buildAuditSnapshot(
        entityType: '',
        entityId: 'id',
        deletedBy: 'admin',
        deletedAt: DateTime.utc(2026, 7, 11),
      ),
      throwsArgumentError,
    );
    expect(
      () => policy.buildAuditSnapshot(
        entityType: 'commune',
        entityId: '',
        deletedBy: 'admin',
        deletedAt: DateTime.utc(2026, 7, 11),
      ),
      throwsArgumentError,
    );
    expect(
      () => policy.buildAuditSnapshot(
        entityType: 'commune',
        entityId: 'id',
        deletedBy: '',
        deletedAt: DateTime.utc(2026, 7, 11),
      ),
      throwsArgumentError,
    );
  });
}
