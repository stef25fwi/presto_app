import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/services/admin_messaging_audit_service.dart';

class _NoUserAuthPlatform extends FirebaseAuthPlatform {
  _NoUserAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;
}

Future<void> _seed(FakeFirebaseFirestore firestore) async {
  final logs = firestore.collection('messaging_admin_logs');
  await logs.doc('log-1').set(<String, dynamic>{
    'adminId': 'admin-a',
    'adminEmail': 'admin-a@ilipresto.fr',
    'adminRole': 'admin',
    'action': 'hide_message',
    'targetType': 'message',
    'targetId': 'message-1',
    'reason': 'contenu signalé',
    'riskLevel': 'high',
    'createdAt': DateTime.utc(2026, 7, 16, 8),
  });
  await logs.doc('log-2').set(<String, dynamic>{
    'adminId': 'admin-b',
    'adminEmail': 'admin-b@ilipresto.fr',
    'adminRole': 'superadmin',
    'action': 'warn_user',
    'targetType': 'user',
    'targetId': 'user-2',
    'reason': 'avertissement',
    'riskLevel': 'medium',
    'createdAt': DateTime.utc(2026, 7, 16, 9),
  });
  await logs.doc('log-3').set(<String, dynamic>{
    'adminId': 'admin-a',
    'adminEmail': 'admin-a@ilipresto.fr',
    'adminRole': 'admin',
    'action': 'hide_message',
    'targetType': 'message',
    'targetId': 'message-3',
    'reason': 'spam',
    'riskLevel': 'high',
    'createdAt': DateTime.utc(2026, 7, 16, 10),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _NoUserAuthPlatform();
  });

  test('watchLogs retourne les événements les plus récents avec la limite',
      () async {
    final firestore = FakeFirebaseFirestore();
    await _seed(firestore);
    final service = AdminMessagingAuditService(firestore: firestore);

    final logs = await service.watchLogs(limit: 2).first;

    expect(logs, hasLength(2));
    expect(logs.map((log) => log.id), <String>['log-3', 'log-2']);
    expect(logs.first.action, 'hide_message');
    expect(logs.first.riskLevel, 'high');
    expect(
      logs.first.createdAt?.millisecondsSinceEpoch,
      DateTime.utc(2026, 7, 16, 10).millisecondsSinceEpoch,
    );
  });

  test('fetchLogsPage pagine avec un curseur et calcule hasMore', () async {
    final firestore = FakeFirebaseFirestore();
    await _seed(firestore);
    final service = AdminMessagingAuditService(firestore: firestore);

    final firstPage = await service.fetchLogsPage(pageSize: 2);
    expect(firstPage.items.map((log) => log.id), <String>['log-3', 'log-2']);
    expect(firstPage.hasMore, isTrue);
    expect(firstPage.lastDocument?.id, 'log-2');

    final secondPage = await service.fetchLogsPage(
      pageSize: 2,
      startAfter: firstPage.lastDocument,
    );
    expect(secondPage.items.map((log) => log.id), <String>['log-1']);
    expect(secondPage.hasMore, isFalse);
    expect(secondPage.lastDocument?.id, 'log-1');
  });

  test('fetchLogsPage applique les filtres risque et action normalisés',
      () async {
    final firestore = FakeFirebaseFirestore();
    await _seed(firestore);
    final service = AdminMessagingAuditService(firestore: firestore);

    final filtered = await service.fetchLogsPage(
      pageSize: 10,
      riskLevel: ' high ',
      action: ' hide_message ',
    );

    expect(filtered.items.map((log) => log.id), <String>['log-3', 'log-1']);
    expect(filtered.hasMore, isFalse);

    final blankFilters = await service.fetchLogsPage(
      pageSize: 10,
      riskLevel: '   ',
      action: ' ',
    );
    expect(blankFilters.items, hasLength(3));
  });

  test('une page vide conserve le curseur précédent', () async {
    final firestore = FakeFirebaseFirestore();
    await _seed(firestore);
    final service = AdminMessagingAuditService(firestore: firestore);
    final ordered = await firestore
        .collection('messaging_admin_logs')
        .orderBy('createdAt', descending: true)
        .get();
    final cursor = ordered.docs.last;

    final page = await service.fetchLogsPage(
      pageSize: 5,
      startAfter: cursor,
    );

    expect(page.items, isEmpty);
    expect(page.lastDocument, same(cursor));
    expect(page.hasMore, isFalse);
  });

  test('logAction écrit un audit complet même sans utilisateur connecté',
      () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminMessagingAuditService(firestore: firestore);

    await service.logAction(
      action: 'restore_message',
      targetType: 'message',
      targetId: 'message-8',
      reason: 'appel accepté',
      riskLevel: 'low',
      before: <String, dynamic>{'hidden': true},
      after: <String, dynamic>{'hidden': false},
    );

    final documents =
        (await firestore.collection('messaging_admin_logs').get()).docs;
    expect(documents, hasLength(1));
    final data = documents.single.data();
    expect(data['adminId'], '');
    expect(data['adminEmail'], '');
    expect(data['adminRole'], 'admin');
    expect(data['action'], 'restore_message');
    expect(data['targetType'], 'message');
    expect(data['targetId'], 'message-8');
    expect(data['reason'], 'appel accepté');
    expect(data['riskLevel'], 'low');
    expect(data['before'], <String, dynamic>{'hidden': true});
    expect(data['after'], <String, dynamic>{'hidden': false});
    expect(data['createdAt'], isNotNull);
  });
}
