import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';

class _NullCredentialPlatform extends UserCredentialPlatform {
  _NullCredentialPlatform({required super.auth}) : super(user: null);
}

class _CancelledFacebookAuthPlatform extends FirebaseAuthPlatform {
  _CancelledFacebookAuthPlatform() : super(appInstance: null);

  Object? providerError;
  var providerCalls = 0;

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
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(null);

  @override
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    providerCalls += 1;
    final error = providerError;
    if (error != null) throw error;
    return _NullCredentialPlatform(auth: this);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CancelledFacebookAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    platform = _CancelledFacebookAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform
      ..providerError = null
      ..providerCalls = 0;
  });

  Future<void> runAction(WidgetTester tester) async {
    final completed = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                try {
                  await AccountSocialAuthActions.signInWithFacebook(
                    context: context,
                    auth: auth,
                    trackLogin: ({authMethod, isNewUser = false}) async {},
                  );
                  completed.complete();
                } catch (error, stackTrace) {
                  completed.completeError(error, stackTrace);
                }
              },
              child: const Text('Connexion'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Connexion'));
    await tester.pump();
    await completed.future.timeout(const Duration(seconds: 5));
    await tester.pump();
  }

  for (final code in <String>[
    'popup-closed-by-user',
    'cancelled-popup-request',
    'cancelled',
  ]) {
    testWidgets('Facebook traite silencieusement $code', (tester) async {
      platform.providerError = FirebaseAuthException(code: code);

      await runAction(tester);

      expect(platform.providerCalls, 1);
      expect(find.text('Erreur de connexion Facebook.'), findsNothing);
      expect(
        find.text('Erreur lors de la connexion Facebook. Reessayez.'),
        findsNothing,
      );
    });
  }

  final firebaseCases = <String, String>{
    'account-exists-with-different-credential':
        'Un compte existe déjà avec cet email. Utilise ta méthode de connexion habituelle.',
    'operation-not-allowed':
        'Connexion Facebook non activée dans Firebase Authentication.',
    'invalid-credential': 'Identifiants Facebook invalides. Réessaie.',
    'network-request-failed': 'Erreur réseau. Vérifie la connexion internet.',
  };

  for (final entry in firebaseCases.entries) {
    testWidgets('Facebook affiche le message dédié pour ${entry.key}',
        (tester) async {
      platform.providerError = FirebaseAuthException(code: entry.key);

      await runAction(tester);

      expect(platform.providerCalls, 1);
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('Facebook conserve un message Firebase explicite', (tester) async {
    platform.providerError = FirebaseAuthException(
      code: 'provider-specific-error',
      message: 'Message Facebook précis.',
    );

    await runAction(tester);

    expect(platform.providerCalls, 1);
    expect(find.text('Message Facebook précis.'), findsOneWidget);
  });

  testWidgets('Facebook utilise le message générique pour une erreur inconnue',
      (tester) async {
    platform.providerError = StateError('échec inattendu');

    await runAction(tester);

    expect(platform.providerCalls, 1);
    expect(
      find.text('Erreur lors de la connexion Facebook. Reessayez.'),
      findsOneWidget,
    );
  });
}
