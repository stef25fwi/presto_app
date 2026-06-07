import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/email_action_service.dart';
import '../../../services/email_auth_error_mapper.dart';
import '../../../services/user_profile_bootstrap_service.dart';
import 'user_profile_service.dart';

class EmailAuthService {
  EmailAuthService({
    FirebaseAuth? auth,
    AuthUserProfileService? profileService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _profileService = profileService ?? AuthUserProfileService();

  final FirebaseAuth _auth;
  final AuthUserProfileService _profileService;

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user ?? _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-token-expired',
        message: 'Session Firebase introuvable après connexion.',
      );
    }
    await UserProfileBootstrapService.ensureUserDocument(
      user: user,
      authMethod: 'email',
      isNewUserHint: false,
    );
    return user;
  }

  Future<User> register({
    required String displayName,
    required String email,
    required String password,
    bool createBusinessProfile = false,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    try {
      await _auth.setLanguageCode('fr');
      await credential.user?.sendEmailVerification();
    } catch (_) {
      // Ne bloque pas la création du compte si l'envoi email échoue.
    }
    final user = credential.user ?? _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-token-expired',
        message: 'Session Firebase introuvable après création du compte.',
      );
    }

    final normalizedDisplayName = displayName.trim();
    if (normalizedDisplayName.isNotEmpty &&
        user.displayName != normalizedDisplayName) {
      await user.updateDisplayName(normalizedDisplayName);
      await user.reload();
    }

    final refreshedUser = _auth.currentUser ?? user;
    await _profileService.ensureEmailUserProfile(
      user: refreshedUser,
      displayName: normalizedDisplayName,
      isBusinessAccount: createBusinessProfile,
    );
    await EmailActionService.requestEmailVerificationEmail();
    return refreshedUser;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: mapEmailAuthError(
          FirebaseAuthException(code: 'missing-email'),
        ),
      );
    }

    try {
      // Priorité au callable backend si disponible : meilleur contrôle sécurité/logs.
      await EmailActionService.requestPasswordResetEmail(normalizedEmail);
    } catch (_) {
      // Fallback Firebase Auth natif pour ne jamais bloquer la récupération.
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    }
  }

  Future<void> requestEmailVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-token-expired',
        message: 'Reconnecte-toi pour recevoir un email de vérification.',
      );
    }
    await EmailActionService.requestEmailVerificationEmail();
  }

  Future<bool> syncCurrentUserEmailVerificationState() {
    return EmailActionService.syncCurrentUserEmailVerificationState();
  }
}
