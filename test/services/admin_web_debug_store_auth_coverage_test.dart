import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_web_debug_store.dart';

class _DebugUser implements User {
  const _DebugUser({required this.id, required this.address});

  final String id;
  final String address;

  @override
  String get uid => id;

  @override
  String? get email => address;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('journalise les transitions auth connecté et déconnecté', () {
    final store = AdminWebDebugStore.instance;
    store.updateAuth(null);
    store.clear();
    const user = _DebugUser(
      id: 'admin-debug-user',
      address: 'admin@ilipresto.fr',
    );

    store.updateAuth(user);
    final eventCountAfterSignIn = store.events.length;
    store.updateAuth(user);

    expect(store.currentUserId, 'admin-debug-user');
    expect(store.currentUserEmail, 'admin@ilipresto.fr');
    expect(store.lastAuthAt, isNotNull);
    expect(store.events.length, eventCountAfterSignIn);
    expect(store.events.first.area, 'auth');
    expect(store.events.first.message, 'signed-in');
    expect(
      store.events.first.detail,
      'admin-debug-user admin@ilipresto.fr',
    );

    store.updateAuth(null);

    expect(store.currentUserId, isNull);
    expect(store.currentUserEmail, isNull);
    expect(store.lastAuthAt, isNotNull);
    expect(store.buildExportReport(), contains('user=null'));
  });
}
