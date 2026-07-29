import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _SafetyBannerMultiFactorPlatform extends MultiFactorPlatform {
  _SafetyBannerMultiFactorPlatform(super.auth);
}

class _SafetyBannerTokenResult extends IdTokenResult {
  _SafetyBannerTokenResult()
    : super(
        InternalIdTokenResult(
          token: 'safety-banner-token',
          claims: const <String?, Object?>{'admin': true},
          authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
          signInProvider: 'password',
        ),
      );
}

class _SafetyBannerUserPlatform extends UserPlatform {
  _SafetyBannerUserPlatform(FirebaseAuthPlatform auth)
    : super(
        auth,
        _SafetyBannerMultiFactorPlatform(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'safety-banner-user',
            email: 'safety-banner-user@ilipresto.fr',
            displayName: 'Utilisateur sécurité',
            isAnonymous: false,
            isEmailVerified: true,
            creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            lastSignInTimestamp: DateTime(2026, 7, 28).millisecondsSinceEpoch,
          ),
          providerData: const <Map<String, dynamic>?>[
            <String, dynamic>{
              'providerId': 'password',
              'uid': 'safety-banner-user',
              'email': 'safety-banner-user@ilipresto.fr',
              'displayName': 'Utilisateur sécurité',
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
  Future<String?> getIdToken(bool forceRefresh) async => 'safety-banner-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async =>
      _SafetyBannerTokenResult();
}

class _SafetyBannerAuthPlatform extends FirebaseAuthPlatform {
  _SafetyBannerAuthPlatform() : super(appInstance: null);

  UserPlatform? user;

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
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

Future<void> _pumpUntilConversationReady(WidgetTester tester) async {
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(TextField).evaluate().isNotEmpty) return;
  }
  fail('Le fil de discussion ne s’est pas affiché après 60 secondes simulées.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SafetyBannerAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _SafetyBannerAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user = _SafetyBannerUserPlatform(authPlatform);
  });

  tearDown(() {
    authPlatform.user = null;
  });

  testWidgets(
    'affiche le triangle et le texte lisible sans débordement sur smartphone',
    (tester) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      const safetyText =
          'Ne partagez jamais de codes, mots de passe ou informations bancaires.';
      const viewportSizes = <Size>[
        Size(320, 640),
        Size(360, 800),
        Size(390, 844),
        Size(430, 932),
      ];

      for (final viewportSize in viewportSizes) {
        await tester.binding.setSurfaceSize(viewportSize);
        await tester.pumpWidget(
          const MaterialApp(
            home: ConversationThreadPage(
              conversationId: 'conversation-safety-banner',
              offerTitle: 'Aide du quotidien',
              currentUserId: 'safety-banner-user',
            ),
          ),
        );
        await _pumpUntilConversationReady(tester);

        expect(
          find.byIcon(Icons.warning_amber_rounded),
          findsOneWidget,
          reason: 'Triangle absent à ${viewportSize.width.toInt()} px.',
        );
        expect(find.byIcon(Icons.shield_outlined), findsNothing);

        final warningIcon = tester.widget<Icon>(
          find.byIcon(Icons.warning_amber_rounded),
        );
        expect(warningIcon.size, 22);
        expect(warningIcon.color, const Color(0xFFFF0000));

        final warningText = tester.widget<Text>(find.text(safetyText));
        expect(warningText.style?.fontSize, 15);
        expect(warningText.style?.height, 1.25);
        expect(warningText.style?.fontWeight, FontWeight.w900);
        expect(warningText.style?.color, const Color(0xFFFF0000));
        expect(find.byTooltip('Masquer'), findsOneWidget);

        expect(
          tester.takeException(),
          isNull,
          reason: 'Débordement ou erreur à ${viewportSize.width.toInt()} px.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        // Le bootstrap du profil arme des `.timeout()` (donc des Timer) qui
        // peuvent être encore en vol au moment où l'arbre est démonté. On
        // laisse l'horloge simulée les faire expirer, sinon le binding
        // signale « A Timer is still pending » en fin de test.
        await tester.pump(const Duration(seconds: 30));
      }
    },
  );
}
