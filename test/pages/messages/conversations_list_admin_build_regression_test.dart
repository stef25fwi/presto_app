import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversations_list_page.dart';

class _BuildRegressionMultiFactorPlatform extends MultiFactorPlatform {
  _BuildRegressionMultiFactorPlatform(super.auth);
}

class _BuildRegressionTokenResult extends IdTokenResult {
  _BuildRegressionTokenResult()
      : super(
          InternalIdTokenResult(
            token: 'admin-build-token',
            claims: const <String?, Object?>{'admin': true},
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _BuildRegressionUserPlatform extends UserPlatform {
  _BuildRegressionUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _BuildRegressionMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'admin-build-regression',
              email: 'admin-build@ilipresto.fr',
              displayName: 'Admin build',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 23).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'admin-build-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async =>
      _BuildRegressionTokenResult();
}

class _BuildRegressionAuthPlatform extends FirebaseAuthPlatform {
  _BuildRegressionAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> controller =
      StreamController<UserPlatform?>.broadcast();
  late final UserPlatform user = _BuildRegressionUserPlatform(this);

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
  Stream<UserPlatform?> authStateChanges() => controller.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => controller.stream;

  @override
  Stream<UserPlatform?> userChanges() => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _BuildRegressionAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _BuildRegressionAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  tearDownAll(() async {
    await authPlatform.controller.close();
  });

  testWidgets('le journal admin ne déclenche aucun setState pendant le build',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationsListPage(appBarTitle: 'Journal admin build'),
      ),
    );

    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.takeException(),
        isNull,
        reason: 'aucune mutation UI ne doit être déclenchée pendant build',
      );
    }

    expect(find.text('Journal admin build'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
