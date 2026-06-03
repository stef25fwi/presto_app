import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/email_action_service.dart';
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
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }
}
