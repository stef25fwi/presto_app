import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class _FakeMultiFactorPlatform extends MultiFactorPlatform {
  _FakeMultiFactorPlatform(super.auth);
}

class _AppleUserPlatform extends UserPlatform {
  _AppleUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _FakeMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'apple-user-1',
              email: 'alice@ilipresto.fr',
              displayName: null,
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 15).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  String? updatedDisplayName;

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    updatedDisplayName = displayName;
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    throw FirebaseException(
      plugin: 'firebase_auth',
      code: 'permission-denied',
      message: 'profile bootstrap intentionally unavailable in widget tests',
    );
  }
}

class _AppleCredentialPlatform extends UserCredentialPlatform {
  _AppleCredentialPlatform({
    required super.auth,
    required UserPlatform user,
    required bool isNewUser,
  }) : super(
          user: user,
          additionalUserInfo: AdditionalUserInfo(isNewUser: isNewUser),
        );
}

class _AppleAuthPlatform extends FirebaseAuthPlatform {
  _AppleAuthPlatform() : super(appInstance: null) {
    user = _AppleUserPlatform(this);
  }

  late final _AppleUserPlatform user;
  Object? credentialError;
  bool isNewUser = true;
  var credentialCalls = 0;
  String? credentialProviderId;

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
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(user);

  @override
  Future<UserCredentialPlatform> signInWithCredential(
    AuthCredential credential,
  ) async {
    credentialCalls += 1;
    credentialProviderId = credential.providerId;
    final error = credentialError;
    if (error != null) throw error;
    return _AppleCredentialPlatform(
      auth: this,
      user: user,
      isNewUser: isNewUser,
    );
  }
}

Map<String, Object?> _appleResponse({
  String? identityToken = 'identity-token',
  String? givenName = 'Alice',
  String? familyName = 'Martin',
}) {
  return <String, Object?>{
    'type': 'appleid',
    'userIdentifier': 'apple-user-1',
    'givenName': givenName,
    'familyName': familyName,
    'authorizationCode': 'authorization-code',
    'email': 'alice@ilipresto.fr',
    'identityToken': identityToken,
    'state': null,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AppleAuthPlatform platform;
  late FirebaseAuth auth;
  late TestDefaultBinaryMessenger messenger;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _AppleAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
    messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  });

  setUp(() {
    platform
      ..credentialError = null
      ..isNewUser = true
      ..credentialCalls = 0
      ..credentialProviderId = null;
    platform.user.updatedDisplayName = null;
    messenger.setMockMethodCallHandler(
      SignInWithApple.channel,
      (call) async => _appleResponse(),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SignInWithApple.channel, null);
  });

  Future<void> runAction(
    WidgetTester tester,
    Future<void> Function(BuildContext context) action,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final completed = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  try {
                    await action(context);
                    completed.complete();
                  } catch (error, stackTrace) {
                    completed.completeError(error, stackTrace);
                  }
                },
                child: const Text('Connexion Apple'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Connexion Apple'));
      await tester.pump();
      await completed.future.timeout(const Duration(seconds: 10));
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> trackLogin({
    String? authMethod,
    bool isNewUser = false,
  }) async {}

  testWidgets('Apple finalise une nouvelle connexion et transmet le profil',
      (tester) async {
    String? trackedMethod;
    bool? trackedNewUser;

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: ({authMethod, isNewUser = false}) async {
          trackedMethod = authMethod;
          trackedNewUser = isNewUser;
        },
      ),
    );

    expect(platform.credentialCalls, 1);
    expect(platform.credentialProviderId, 'apple.com');
    expect(platform.user.updatedDisplayName, 'Alice Martin');
    expect(trackedMethod, 'apple');
    expect(trackedNewUser, isTrue);
    expect(find.text('Connecte avec Apple ✓'), findsOneWidget);
  });

  testWidgets('Apple accepte une connexion existante sans nom', (tester) async {
    platform.isNewUser = false;
    messenger.setMockMethodCallHandler(
      SignInWithApple.channel,
      (call) async => _appleResponse(givenName: null, familyName: null),
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: trackLogin,
      ),
    );

    expect(platform.credentialCalls, 1);
    expect(platform.user.updatedDisplayName, isNull);
    expect(find.text('Connecte avec Apple ✓'), findsOneWidget);
  });

  final authorizationErrors = <String, String>{
    'authorization-error/canceled': 'Connexion Apple annulée.',
    'authorization-error/credentialExport':
        'Export des identifiants Apple non pris en charge sur cet appareil.',
    'authorization-error/credentialImport':
        'Import des identifiants Apple non pris en charge sur cet appareil.',
    'authorization-error/failed':
        'Échec de l\'authentification Apple. Réessaye.',
    'authorization-error/invalidResponse':
        'Réponse Apple invalide. Contacte le support.',
    'authorization-error/notHandled': 'Requête Apple non traitée.',
    'authorization-error/notInteractive':
        'Authentification Apple non disponible en arrière-plan.',
    'authorization-error/unknown': 'Erreur Apple inconnue. Réessaye.',
  };

  for (final entry in authorizationErrors.entries) {
    testWidgets('Apple traduit ${entry.key}', (tester) async {
      messenger.setMockMethodCallHandler(
        SignInWithApple.channel,
        (call) async => throw PlatformException(
          code: entry.key,
          message: 'native failure',
        ),
      );

      await runAction(
        tester,
        (context) => AccountSocialAuthActions.signInWithApple(
          context: context,
          auth: auth,
          trackLogin: trackLogin,
        ),
      );

      expect(platform.credentialCalls, 0);
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  final firebaseErrors = <String, String>{
    'account-exists-with-different-credential':
        'Un compte existe déjà avec cet email. Utilise ta méthode de connexion habituelle.',
    'invalid-credential': 'Credentials Apple invalides. Réessaye.',
    'operation-not-allowed': 'Connexion Apple non activée. Contacte le support.',
    'user-disabled': 'Ce compte a été désactivé.',
    'user-not-found': 'Aucun compte trouvé. Un nouveau compte sera créé.',
    'invalid-verification-code': 'Code de vérification Apple invalide.',
    'invalid-verification-id': 'Code de vérification Apple invalide.',
  };

  for (final entry in firebaseErrors.entries) {
    testWidgets('Apple traduit l erreur Firebase ${entry.key}', (tester) async {
      platform.credentialError = FirebaseAuthException(code: entry.key);

      await runAction(
        tester,
        (context) => AccountSocialAuthActions.signInWithApple(
          context: context,
          auth: auth,
          trackLogin: trackLogin,
        ),
      );

      expect(platform.credentialCalls, 1);
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('Apple conserve le détail d une erreur Firebase inconnue',
      (tester) async {
    platform.credentialError = FirebaseAuthException(
      code: 'unknown',
      message: 'service Apple indisponible',
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: trackLogin,
      ),
    );

    expect(
      find.text('Erreur Firebase : service Apple indisponible'),
      findsOneWidget,
    );
  });

  testWidgets('Apple refuse une réponse sans jeton d identité', (tester) async {
    messenger.setMockMethodCallHandler(
      SignInWithApple.channel,
      (call) async => _appleResponse(identityToken: null),
    );

    await runAction(
      tester,
      (context) => AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: auth,
        trackLogin: trackLogin,
      ),
    );

    expect(platform.credentialCalls, 0);
    expect(
      find.textContaining('Erreur inattendue : Exception: Identité Apple non reçue'),
      findsOneWidget,
    );
  });
}
