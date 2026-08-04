import 'dart:async';

// L'interface de plateforme est utilisée volontairement : c'est le seul point
// d'injection permettant de rendre un écran réel sans backend.
// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

/// Harnais Firebase partagé par les tests de widgets.
///
/// Sans lui, chaque fichier réimplémentait sa propre doublure
/// d'authentification — une centaine de lignes recopiées, avec des variantes
/// d'initialisation qui finissaient par se contredire et provoquer des
/// `core/duplicate-app`. Le harnais centralise l'initialisation, la rend
/// idempotente, et fournit un utilisateur déterministe.

bool _coreInitialized = false;

/// Initialise Firebase pour les tests, une seule fois par isolat.
///
/// `initializeApp` est appelée sans options : les mocks du cœur exposent déjà
/// une application par défaut, et lui en fournir une seconde déclenche
/// `core/duplicate-app`.
Future<void> ensureFirebaseInitialized() async {
  if (_coreInitialized) return;
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
  _coreInitialized = true;
}

/// Profil injecté dans l'utilisateur de test.
class PrestoTestUserProfile {
  const PrestoTestUserProfile({
    this.uid = 'utilisateur-test',
    this.email = 'utilisateur-test@ilipresto.fr',
    this.displayName = 'Utilisateur de test',
    this.emailVerified = true,
    this.claims = const <String, Object?>{},
  });

  final String uid;
  final String email;
  final String displayName;
  final bool emailVerified;

  /// Revendications portées par le jeton, rôles d'administration compris.
  final Map<String, Object?> claims;
}

class _TestMultiFactor extends MultiFactorPlatform {
  _TestMultiFactor(super.auth);
}

class _TestIdTokenResult extends IdTokenResult {
  _TestIdTokenResult(Map<String, Object?> claims)
      : super(
          InternalIdTokenResult(
            token: 'jeton-de-test',
            claims: claims.map((key, value) => MapEntry<String?, Object?>(key, value)),
            authTimestamp: DateTime.utc(2026).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime.utc(2026).millisecondsSinceEpoch,
            expirationTimestamp: DateTime.utc(2027).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class PrestoTestUser extends UserPlatform {
  PrestoTestUser(FirebaseAuthPlatform auth, this.profile)
      : super(
          auth,
          _TestMultiFactor(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: profile.uid,
              email: profile.email,
              displayName: profile.displayName,
              isAnonymous: false,
              isEmailVerified: profile.emailVerified,
              creationTimestamp: DateTime.utc(2026).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime.utc(2026, 7).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': profile.uid,
                'email': profile.email,
                'displayName': profile.displayName,
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': profile.emailVerified,
              },
            ],
          ),
        );

  final PrestoTestUserProfile profile;

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'jeton-de-test';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async =>
      _TestIdTokenResult(profile.claims);

  @override
  Future<void> reload() async {}
}

/// Authentification déterministe : aucun appel réseau, un état contrôlé.
class PrestoTestAuthPlatform extends FirebaseAuthPlatform {
  PrestoTestAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> _controller =
      StreamController<UserPlatform?>.broadcast();

  UserPlatform? _user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => _user;

  @override
  Stream<UserPlatform?> authStateChanges() => _controller.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => _controller.stream;

  @override
  Stream<UserPlatform?> userChanges() => _controller.stream;

  /// Connecte un utilisateur et notifie les écrans à l'écoute.
  PrestoTestUser signIn([
    PrestoTestUserProfile profile = const PrestoTestUserProfile(),
  ]) {
    final user = PrestoTestUser(this, profile);
    _user = user;
    _controller.add(user);
    return user;
  }

  /// Déconnecte l'utilisateur courant.
  void signOutUser() {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> dispose() => _controller.close();
}

/// Installe une authentification de test et restaure l'instance précédente.
///
/// À appeler dans un `setUp` ; la restauration est enregistrée auprès du test
/// courant, ce qui évite qu'un fichier laisse une doublure derrière lui.
Future<PrestoTestAuthPlatform> installTestAuth({
  required void Function(Future<void> Function()) addTearDown,
  PrestoTestUserProfile? signedInAs,
}) async {
  await ensureFirebaseInitialized();
  final previous = FirebaseAuthPlatform.instance;
  final platform = PrestoTestAuthPlatform();
  FirebaseAuthPlatform.instance = platform;
  if (signedInAs != null) platform.signIn(signedInAs);
  addTearDown(() async {
    FirebaseAuthPlatform.instance = previous;
    await platform.dispose();
  });
  return platform;
}
