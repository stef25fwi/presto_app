import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthStatus {
  loading,
  signedOut,
  signedInUnverified,
  signedInVerified,
  disabled,
  error,
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? fullName,
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
        await GoogleSignIn.instance.signOut();
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
    final user = _requireUser();

    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'emailVerified': user.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    required String password,
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
      password: password,
    );

    await user.reauthenticateWithCredential(credential);

    await _db.collection('users').doc(user.uid).set({
      'accountStatus': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'email': null,
      'displayName': 'Utilisateur supprimé',
      'phoneNumber': null,
      'photoUrl': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.delete();
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
    final snap = await ref.get();

    final data = <String, Object?>{
      'uid': user.uid,
      'email': user.email,
      'emailVerified': user.emailVerified,
      'displayName': user.displayName,
      'phoneNumber': user.phoneNumber,
      'accountStatus': 'active',
      'role': 'user',
      'updatedAt': FieldValue.serverTimestamp(),
      ...extra,
    };

    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

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
