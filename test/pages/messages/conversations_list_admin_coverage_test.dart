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
    required this.claims,
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
  final Map<String?, Object?> claims;
  var tokenCalls = 0;
  var tokenResultCalls = 0;

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    tokenCalls += 1;
    return 'messages-admin-token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    tokenResultCalls += 1;
    return _AdminListTokenResult(claims);
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

  Future<_AdminListUserPlatform> pumpAdmin(
    WidgetTester tester, {
    required Map<String?, Object?> claims,
  }) async {
    final user = _AdminListUserPlatform(
      authPlatform,
      userId: 'admin-messages-${claims.hashCode}',
      claims: claims,
    );
    authPlatform.user = user;
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationsListPage(appBarTitle: 'Journal messagerie'),
      ),
    );
    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    return user;
  }

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('les claims admin map activent et déplient le journal',
      (tester) async {
    final user = await pumpAdmin(
      tester,
      claims: <String?, Object?>{
        'roles': <String, bool>{'admin': true, 'viewer': false},
        'primaryRole': ' SUPERADMIN ',
      },
    );

    expect(user.tokenResultCalls, greaterThan(0));
    expect(find.text('Journal messagerie'), findsOneWidget);
    expect(find.text('Log admin - chargement conversations'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsOneWidget);

    await tester.tap(find.text('Log admin - chargement conversations'));
    await tester.pump();

    expect(find.byTooltip('Copier les logs'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);

    await tester.tap(find.byTooltip('Copier les logs'));
    await tester.pump();
    expect(find.text('Logs copiés dans le presse-papiers.'), findsOneWidget);

    await disposePage(tester);
  });

  testWidgets('les claims admin texte activent la vue globale', (tester) async {
    final user = await pumpAdmin(
      tester,
      claims: const <String?, Object?>{
        'roles': ' user, ADMIN ',
      },
    );

    expect(user.tokenResultCalls, greaterThan(0));
    expect(find.text('Log admin - chargement conversations'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await disposePage(tester);
  });
}
