import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversations_list_page.dart';

class _AdminListMultiFactorPlatform extends MultiFactorPlatform {
  _AdminListMultiFactorPlatform(super.auth);
}

class _AdminListTokenResult extends IdTokenResult {
  _AdminListTokenResult(Map<String?, Object?> claims)
      : super(
          InternalIdTokenResult(
            token: 'messages-admin-token',
            claims: claims,
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _AdminListUserPlatform extends UserPlatform {
  _AdminListUserPlatform(
    FirebaseAuthPlatform auth, {
    required this.userId,
  }) : super(
          auth,
          _AdminListMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: userId,
              email: '$userId@ilipresto.fr',
              displayName: 'Administrateur messagerie',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 23).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': userId,
                'email': '$userId@ilipresto.fr',
                'displayName': 'Administrateur messagerie',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );

  final String userId;
  final Completer<IdTokenResult> tokenResult = Completer<IdTokenResult>();
  var tokenResultCalls = 0;

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'messages-admin-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) {
    tokenResultCalls += 1;
    return tokenResult.future;
  }
}

class _AdminListAuthPlatform extends FirebaseAuthPlatform {
  _AdminListAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> controller =
      StreamController<UserPlatform?>.broadcast();
  UserPlatform? user;

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

  late _AdminListAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _AdminListAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  tearDown(() {
    authPlatform.user = null;
  });

  tearDownAll(() async {
    await authPlatform.controller.close();
  });

  Future<void> drainNativeAppCheckRetries(WidgetTester tester) async {
    // Le préflight non bloquant utilise sur VM deux tentatives de 12 secondes,
    // séparées par un backoff de 1 seconde. L'horloge Flutter est virtuelle :
    // ces pumps n'ajoutent aucune attente murale à la CI.
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
  }

  Future<_AdminListUserPlatform> pumpAdminPage(
    WidgetTester tester, {
    required String userId,
  }) async {
    final user = _AdminListUserPlatform(authPlatform, userId: userId);
    authPlatform.user = user;
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationsListPage(appBarTitle: 'Journal messagerie'),
      ),
    );
    for (var frame = 0; frame < 8 && user.tokenResultCalls == 0; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ConversationsListPage), findsOneWidget);
    expect(find.text('Journal messagerie'), findsOneWidget);
    expect(user.tokenResultCalls, greaterThan(0));
    return user;
  }

  Future<void> exerciseClaimsAfterUnmount(
    WidgetTester tester, {
    required Map<String?, Object?> claims,
  }) async {
    final user = await pumpAdminPage(
      tester,
      userId: 'admin-messages-${claims.hashCode}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    user.tokenResult.complete(_AdminListTokenResult(claims));
    await tester.pump();
    await drainNativeAppCheckRetries(tester);
    expect(tester.takeException(), isNull);
  }

  void expectNoBuildMutation(Object? exception) {
    if (exception == null) return;
    final message = exception.toString();
    expect(
      message.contains('setState() or markNeedsBuild() called during build'),
      isFalse,
    );
    expect(message.contains('setState() called during build'), isFalse);
    expect(
      message,
      contains('ListTile background color or ink splashes may be invisible'),
      reason: 'seul l avertissement visuel ListTile existant est toléré',
    );
  }

  testWidgets('normalise les claims admin fournis sous forme de map',
      (tester) async {
    await exerciseClaimsAfterUnmount(
      tester,
      claims: <String?, Object?>{
        'roles': <String, bool>{'admin': true, 'viewer': false},
        'primaryRole': ' SUPERADMIN ',
      },
    );
  });

  testWidgets('normalise les claims admin fournis sous forme de texte',
      (tester) async {
    await exerciseClaimsAfterUnmount(
      tester,
      claims: const <String?, Object?>{
        'roles': ' user, ADMIN ',
      },
    );
  });

  testWidgets('reporte les mutations du journal admin après le build',
      (tester) async {
    final user = await pumpAdminPage(
      tester,
      userId: 'admin-messages-build-regression',
    );
    user.tokenResult.complete(
      _AdminListTokenResult(
        const <String?, Object?>{
          'roles': <String, bool>{'admin': true},
          'primaryRole': 'admin',
        },
      ),
    );

    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      expectNoBuildMutation(tester.takeException());
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await drainNativeAppCheckRetries(tester);
    expectNoBuildMutation(tester.takeException());
  });
}
