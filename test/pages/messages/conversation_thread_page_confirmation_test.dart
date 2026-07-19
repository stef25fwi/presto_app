import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _MultiFactorPlatform extends MultiFactorPlatform {
  _MultiFactorPlatform(super.auth);
}

class _TokenResult extends IdTokenResult {
  _TokenResult()
      : super(
          InternalIdTokenResult(
            token: 'confirmation-token',
            claims: const <String?, Object?>{'admin': true},
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _UserPlatform extends UserPlatform {
  _UserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _MultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'thread-user',
              email: 'thread-user@ilipresto.fr',
              displayName: 'Utilisateur conversation',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 19).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'confirmation-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    return _TokenResult();
  }
}

class _AuthPlatform extends FirebaseAuthPlatform {
  _AuthPlatform() : super(appInstance: null);

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
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

Future<void> _pumpUntilReady(WidgetTester tester) async {
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(TextField).evaluate().isNotEmpty) return;
  }
  fail('Le fil de conversation ne s’est pas affiché.');
}

Future<void> _disposeAfterBootstrap(WidgetTester tester) async {
  const preparingLabel = 'Preparation securisee de la messagerie…';
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text(preparingLabel).evaluate().isEmpty) break;
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _AuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user = _UserPlatform(authPlatform);
  });

  tearDown(() {
    authPlatform.user = null;
  });

  Future<void> pumpThread(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationThreadPage(
          conversationId: 'conversation-confirmations',
          offerTitle: 'Peinture salon',
          currentUserId: 'thread-user',
        ),
      ),
    );
    await _pumpUntilReady(tester);
  }

  testWidgets('annule la confirmation de suppression sans supprimer le fil',
      (tester) async {
    await pumpThread(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(milliseconds: 300));

    final deleteMenuItem = find.ancestor(
      of: find.text('Supprimer'),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
    );
    expect(deleteMenuItem, findsOneWidget);
    await tester.tap(deleteMenuItem);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await _disposeAfterBootstrap(tester);
  });

  testWidgets('ferme la feuille des pièces jointes sans lancer de sélection',
      (tester) async {
    await pumpThread(tester);

    await tester.tap(find.byTooltip('Ajouter une pièce jointe'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Fichier'), findsOneWidget);

    Navigator.of(tester.element(find.text('Photo'))).pop();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Photo'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await _disposeAfterBootstrap(tester);
  });
}
