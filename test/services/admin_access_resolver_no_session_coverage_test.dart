import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _NoSessionAuthPlatform extends FirebaseAuthPlatform {
  _NoSessionAuthPlatform() : super(appInstance: null);

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

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _NoSessionAuthPlatform();
  });

  test('finalise immédiatement un refus administrateur sans session', () async {
    final resolver = AdminAccessResolver(
      auth: FirebaseAuth.instance,
      firestore: FakeFirebaseFirestore(),
    );

    final state = await resolver.resolveAdminAccess();

    expect(state.isAuthenticated, isFalse);
    expect(state.effectiveIsAdmin, isFalse);
    expect(state.sourceOfTruth, 'none');
    expect(state.uid, isNull);
  });

  test('le mode forceRefresh conserve le même refus sans utilisateur', () async {
    final resolver = AdminAccessResolver(
      auth: FirebaseAuth.instance,
      firestore: FakeFirebaseFirestore(),
    );

    final state = await resolver.resolveAdminAccess(
      forceRefresh: true,
      returnOnLocalAdminEvidence: true,
    );

    expect(state.isAuthenticated, isFalse);
    expect(state.effectiveIsAdmin, isFalse);
    expect(state.sourceOfTruth, 'none');
  });
}
