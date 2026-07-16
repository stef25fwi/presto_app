import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_functions_region.dart';

typedef AuthFunctionCaller = Future<void> Function({
  required String name,
  required Duration timeout,
  required Map<String, dynamic> parameters,
  required String area,
});

typedef AuthGoogleSignOut = Future<void> Function();

enum AuthStatus {
  loading,
  signedOut,
  signedInUnverified,
  signedInVerified,
  disabled,
  error,
}

class AuthService {
  AuthService._({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AuthFunctionCaller? functionCaller,
    AuthGoogleSignOut? googleSignOut,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _functionsOverride = functions,
        _functionCaller = functionCaller,
        _googleSignOut = googleSignOut;

  static final AuthService instance = AuthService._();

  @visibleForTesting
  factory AuthService.forTesting({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    FirebaseFunctions? functions,
    AuthFunctionCaller? functionCaller,
    AuthGoogleSignOut? googleSignOut,
  }) {
    return AuthService._(
      auth: auth,
      firestore: firestore,
      functions: functions,
      functionCaller: functionCaller,
      googleSignOut: googleSignOut,
    );
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions? _functionsOverride;
  final AuthFunctionCaller? _functionCaller;
  final AuthGoogleSignOut? _googleSignOut;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? prestoFirebaseFunctions;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userChanges => _auth.userChanges();

  Stream<AuthStatus> get authStatusChanges {
    return _auth.userChanges().map((user) {
      if (user == null) return AuthStatus.signedOut;
      if (!user.emailVerified && _isPasswordUser(user)) {
        return AuthStatus.signedInUnverified;
      }
      return AuthStatus.signedInVerified;
    });
  }

  bool _isPasswordUser(User user) {
    return user.providerData
        .any((provider) => provider.providerId == 'password');
  }

  ActionCodeSettings get _emailActionSettings {
    return ActionCodeSettings(
      url: 'https://www.ilipresto.fr/auth/action',
      handleCodeInApp: false,
    );
  }

  Future<void> _callFunction({
    required String name,
    required Duration timeout,
    required Map<String, dynamic> parameters,
    required String area,
  }) async {
    final override = _functionCaller;
    if (override != null) {
      await override(
        name: name,
        timeout: timeout,
        parameters: parameters,
        area: area,
      );
      return;
    }

    await callPrestoFunction<dynamic>(
      functions: _functions,
      name: name,
      timeout: timeout,
      parameters: parameters,
      area: area,
    );
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? fullName,
    String? firstName,
    String? lastName,
    String? pseudo,
  }) async {
    await _auth.setLanguageCode('fr');

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-null',
        message: 'Utilisateur introuvable après inscription.',
      );
    }

    final resolvedPseudo = (pseudo?.trim().isNotEmpty == true)
        ? pseudo!.trim()
        : displayName.trim();

    if (resolvedPseudo.isNotEmpty) {
      await user.updateDisplayName(resolvedPseudo);
    }

    await _upsertUserProfile(
      user,
      extra: {
        'displayName': resolvedPseudo,
        'pseudo': resolvedPseudo,
        if (fullName != null && fullName.trim().isNotEmpty)
          'fullName': fullName.trim(),
        if (firstName != null && firstName.trim().isNotEmpty)
          'firstName': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'lastName': lastName.trim(),
        'authProvider': 'password',
      },
    );

    await sendEmailVerificationLink();

    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.setLanguageCode('fr');

    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await user.reload();
      await _upsertUserProfile(
        _auth.currentUser ?? user,
        extra: {
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
      );
    }

    return credential;
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        final override = _googleSignOut;
        if (override != null) {
          await override();
        } else {
          await GoogleSignIn.instance.signOut();
        }
      }
    } catch (_) {
      // Ignore si GoogleSignIn n’est pas initialisé.
    }

    await _auth.signOut();
  }

  Future<void> sendPasswordReset({
    required String email,
  }) async {
    await _auth.setLanguageCode('fr');

    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: _emailActionSettings,
      );
    } on FirebaseAuthException catch (e) {
      // Message neutre côté UI pour éviter d’indiquer si un compte existe.
      if (e.code == 'user-not-found') return;
      rethrow;
    }
  }

  Future<void> sendEmailVerificationLink() async {
    await _auth.setLanguageCode('fr');

    final user = _requireUser();
    await user.reload();

    final refreshedUser = _requireUser();
    if (refreshedUser.emailVerified) {
      await syncEmailVerifiedToFirestore();
      return;
    }

    await refreshedUser.sendEmailVerification(_emailActionSettings);
  }

  Future<void> resendVerificationEmail() async {
    await sendEmailVerificationLink();
  }

  Future<bool> checkEmailVerified() async {
    final user = _requireUser();
    await user.reload();

    final refreshedUser = _requireUser();
    final verified = refreshedUser.emailVerified;

    if (verified) {
      await syncEmailVerifiedToFirestore();
    }

    return verified;
  }

  Future<void> syncEmailVerifiedToFirestore() async {
    _requireUser();
    await _callFunction(
      name: 'syncMyEmailVerification',
      timeout: const Duration(seconds: 15),
      parameters: const <String, dynamic>{},
      area: 'auth',
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _requireUser();
    final email = user.email;

    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Email du compte introuvable.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);

    await _db.collection('users').doc(user.uid).set({
      'passwordChangedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _requireUser();
    final currentEmail = user.email;

    if (currentEmail == null || currentEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Email actuel introuvable.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: currentEmail,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);

    await _db.collection('users').doc(user.uid).set({
      'pendingEmail': newEmail.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.verifyBeforeUpdateEmail(
      newEmail.trim(),
      _emailActionSettings,
    );
  }

  Future<void> deleteCurrentAccount({
    String? password,
  }) async {
    final user = _requireUser();

    if (_isPasswordUser(user)) {
      final email = user.email;
      final normalizedPassword = password ?? '';
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: 'Email du compte introuvable.',
        );
      }
      if (normalizedPassword.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-password',
          message: 'Mot de passe obligatoire.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: normalizedPassword,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      final lastSignIn = user.metadata.lastSignInTime;
      final isRecent = lastSignIn != null &&
          DateTime.now().difference(lastSignIn) <= const Duration(minutes: 10);
      if (!isRecent) {
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message:
              'Reconnecte-toi avec Google ou Apple avant de supprimer le compte.',
        );
      }
    }

    await _callFunction(
      name: 'requestAccountDeletion',
      timeout: const Duration(seconds: 120),
      parameters: const <String, dynamic>{},
      area: 'account-deletion',
    );

    try {
      await _auth.signOut();
    } catch (_) {
      // Le backend a déjà supprimé le compte Auth : la session locale peut être invalide.
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    await _auth.setLanguageCode('fr');

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final credential = await _auth.signInWithPopup(provider);
      await _afterSocialLogin(credential, providerName: 'google');
      return credential;
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await _afterSocialLogin(userCredential, providerName: 'google');
    return userCredential;
  }

  Future<UserCredential> signInWithApple() async {
    await _auth.setLanguageCode('fr');

    final provider = AppleAuthProvider();

    final credential = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);

    await _afterSocialLogin(credential, providerName: 'apple');

    return credential;
  }

  Future<void> _afterSocialLogin(
    UserCredential credential, {
    required String providerName,
  }) async {
    final user = credential.user;
    if (user == null) return;

    await _upsertUserProfile(
      user,
      extra: {
        'authProvider': providerName,
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _upsertUserProfile(
    User user, {
    Map<String, Object?> extra = const {},
  }) async {
    final ref = _db.collection('users').doc(user.uid);

    // Les rôles, l’état du compte, l’abonnement et createdAt sont exclusivement
    // créés par le backend. Le client n’écrit que des champs de profil sûrs.
    final data = <String, Object?>{
      'displayName': user.displayName,
      'phoneNumber': user.phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
      ...extra,
    };

    await ref.set(data, SetOptions(merge: true));
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Utilisateur non connecté.',
      );
    }

    return user;
  }
}
