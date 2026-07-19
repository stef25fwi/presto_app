import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _InteractionMultiFactorPlatform extends MultiFactorPlatform {
  _InteractionMultiFactorPlatform(super.auth);
}

class _InteractionTokenResult extends IdTokenResult {
  _InteractionTokenResult()
      : super(
          InternalIdTokenResult(
            token: 'interaction-token',
            claims: const <String?, Object?>{'admin': true},
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _InteractionUserPlatform extends UserPlatform {
  _InteractionUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _InteractionMultiFactorPlatform(auth),
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
            providerData: const <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': 'thread-user',
                'email': 'thread-user@ilipresto.fr',
                'displayName': 'Utilisateur conversation',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'interaction-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    return _InteractionTokenResult();
  }
}

class _InteractionAuthPlatform extends FirebaseAuthPlatform {
  _InteractionAuthPlatform() : super(appInstance: null);

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

Future<void> _pumpUntilDraft(
  WidgetTester tester,
  String expectedText,
) async {
  for (var frame = 0; frame < 20; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    final fields = find.byType(TextField).evaluate();
    if (fields.isEmpty) continue;
    final field = tester.widget<TextField>(find.byType(TextField));
    if (field.controller?.text == expectedText) return;
  }
  final field = tester.widget<TextField>(find.byType(TextField));
  fail(
    'Le brouillon initial n’a pas été synchronisé. '
    'Attendu: $expectedText, obtenu: ${field.controller?.text}',
  );
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

  late _InteractionAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _InteractionAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user = _InteractionUserPlatform(authPlatform);
  });

  tearDown(() {
    authPlatform.user = null;
  });

  Future<void> pumpThread(
    WidgetTester tester, {
    String? initialDraftText,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationThreadPage(
          conversationId: 'conversation-interactions',
          offerTitle: 'Peinture salon',
          currentUserId: 'thread-user',
          initialDraftText: initialDraftText,
        ),
      ),
    );
    await _pumpUntilReady(tester);
  }

  testWidgets('applique une seule fois le brouillon initial', (tester) async {
    const initialDraft = 'Bonjour, cette offre est-elle disponible ?';
    await pumpThread(
      tester,
      initialDraftText: initialDraft,
    );
    await _pumpUntilDraft(tester, initialDraft);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, initialDraft);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Brouillon modifié');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Brouillon modifié',
    );

    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Brouillon modifié',
    );

    await _disposeAfterBootstrap(tester);
  });

  testWidgets('insère un emoji rapide puis referme la barre', (tester) async {
    await pumpThread(tester);

    await tester.tap(find.byTooltip('Emoji'));
    await tester.pump();
    expect(find.text('👍'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);

    await tester.tap(find.text('👍'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '👍',
    );
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_rounded));
    await tester.pump();
    expect(find.text('🙏'), findsNothing);
    expect(find.byTooltip('Emoji'), findsOneWidget);

    await _disposeAfterBootstrap(tester);
  });
}
