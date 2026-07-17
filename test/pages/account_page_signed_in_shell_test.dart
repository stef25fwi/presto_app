import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/account/signed_out_account_fallback.dart';
import 'package:presto_app/pages/account_page.dart';

class _AccountMultiFactorPlatform extends MultiFactorPlatform {
  _AccountMultiFactorPlatform(super.auth);
}

class _AccountUserPlatform extends UserPlatform {
  _AccountUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _AccountMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'account-shell-user',
              email: 'account-shell-user@ilipresto.fr',
              displayName: 'Compte test',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 17).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': 'account-shell-user',
                'email': 'account-shell-user@ilipresto.fr',
                'displayName': 'Compte test',
                'phoneNumber': '+590690000000',
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );
}

class _SignedInAccountAuthPlatform extends FirebaseAuthPlatform {
  _SignedInAccountAuthPlatform() : super(appInstance: null) {
    user = _AccountUserPlatform(this);
  }

  late final UserPlatform user;
  final StreamController<UserPlatform?> _authController =
      StreamController<UserPlatform?>.broadcast();
  final StreamController<UserPlatform?> _idTokenController =
      StreamController<UserPlatform?>.broadcast();
  final StreamController<UserPlatform?> _userController =
      StreamController<UserPlatform?>.broadcast();

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() => _authController.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => _idTokenController.stream;

  @override
  Stream<UserPlatform?> userChanges() => _userController.stream;

  bool get hasIdTokenListener => _idTokenController.hasListener;

  void emitSignedIn() => _idTokenController.add(user);

  Future<void> disposeControllers() async {
    await _authController.close();
    await _idTokenController.close();
    await _userController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SignedInAccountAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _SignedInAccountAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  tearDownAll(() async {
    await authPlatform.disposeControllers();
  });

  testWidgets('quitte la restauration quand une session connectée est émise',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AccountPage()));

    for (var frame = 0; frame < 20 && !authPlatform.hasIdTokenListener; frame++) {
      await tester.pump();
    }
    expect(authPlatform.hasIdTokenListener, isTrue);
    expect(find.text('Restauration de la session…'), findsOneWidget);

    authPlatform.emitSignedIn();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SignedOutAccountFallback), findsNothing);
    expect(find.text('Restauration de la session…'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
