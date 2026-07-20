import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_service.dart';

class _SessionAuthPlatform extends FirebaseAuthPlatform {
  _SessionAuthPlatform() : super(appInstance: null);

  UserPlatform? user;
  Object? signOutError;
  var signOutCalls = 0;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    final error = signOutError;
    if (error != null) throw error;
    user = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SessionAuthPlatform platform;
  late AuthService service;
  late int googleSignOutCalls;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _SessionAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    googleSignOutCalls = 0;
    platform
      ..user = null
      ..signOutError = null
      ..signOutCalls = 0;
    service = AuthService.forTesting(
      auth: FirebaseAuth.instance,
      firestore: FakeFirebaseFirestore(),
      googleSignOut: () async {
        googleSignOutCalls += 1;
      },
    );
  });

  test('expose une session absente dans les trois API de lecture', () async {
    expect(service.currentUser, isNull);
    await expectLater(service.userChanges, emits(isNull));
    await expectLater(
      service.authStatusChanges,
      emits(AuthStatus.signedOut),
    );
  });

  test('termine la déconnexion Google puis Firebase', () async {
    await service.signOut();

    expect(googleSignOutCalls, 1);
    expect(platform.signOutCalls, 1);
    expect(service.currentUser, isNull);
  });

  test('propage une erreur Firebase de déconnexion après la phase Google',
      () async {
    final expected = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'Réseau indisponible',
    );
    platform.signOutError = expected;

    await expectLater(service.signOut(), throwsA(same(expected)));
    expect(googleSignOutCalls, 1);
    expect(platform.signOutCalls, 1);
  });
}