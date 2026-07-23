import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/email_action_service.dart';
import '../../../services/email_auth_error_mapper.dart';
import '../../../services/user_profile_bootstrap_service.dart';
import 'user_profile_service.dart';

typedef EmailPasswordResetAction = Future<void> Function(String email);
typedef EmailVerificationAction = Future<void> Function();
typedef EmailVerificationSyncAction = Future<bool> Function();
typedef AuthenticatedUserCheck = bool Function();
typedef AuthUserProfileServiceFactory = AuthUserProfileService Function();
typedef EnsureSignedInUserProfileAction = Future<void> Function({
  required User user,
  required String authMethod,
  required bool isNewUserHint,
});
typedef EnsureEmailUserProfileAction = Future<void> Function({
  required User user,
  required String displayName,
  required bool isBusinessAccount,
});

class EmailAuthService {
  EmailAuthService({
    FirebaseAuth? auth,
    AuthUserProfileService? profileService,
    AuthUserProfileServiceFactory? profileServiceFactory,
    EmailPasswordResetAction? backendPasswordReset,
    EmailPasswordResetAction? nativePasswordReset,
    EmailPasswordResetAction? defaultBackendPasswordReset,
    EmailVerificationAction? requestEmailVerification,
    EmailVerificationAction? defaultRequestEmailVerification,
    EmailVerificationSyncAction? syncEmailVerification,
    EmailVerificationSyncAction? defaultSyncEmailVerification,
    AuthenticatedUserCheck? hasCurrentUser,
    EnsureSignedInUserProfileAction? ensureSignedInUserProfile,
    EnsureSignedInUserProfileAction? defaultEnsureSignedInUserProfile,
    EnsureEmailUserProfileAction? ensureEmailUserProfile,
  })  : _auth = auth,
        _profileService = profileService,
        _profileServiceFactory =
            profileServiceFactory ?? AuthUserProfileService.new,
        _backendPasswordReset = backendPasswordReset,
        _nativePasswordReset = nativePasswordReset,
        _defaultBackendPasswordReset = defaultBackendPasswordReset ??
            EmailActionService.requestPasswordResetEmail,
        _requestEmailVerification = requestEmailVerification,
        _defaultRequestEmailVerification = defaultRequestEmailVerification ??
            EmailActionService.requestEmailVerificationEmail,
        _syncEmailVerification = syncEmailVerification,
        _defaultSyncEmailVerification = defaultSyncEmailVerification ??
            EmailActionService.syncCurrentUserEmailVerificationState,
        _hasCurrentUser = hasCurrentUser,
        _ensureSignedInUserProfile = ensureSignedInUserProfile,
        _defaultEnsureSignedInUserProfile = defaultEnsureSignedInUserProfile ??
            UserProfileBootstrapService.ensureUserDocument,
        _ensureEmailUserProfile = ensureEmailUserProfile;

  final FirebaseAuth? _auth;
  final AuthUserProfileService? _profileService;
  final AuthUserProfileServiceFactory _profileServiceFactory;
  final EmailPasswordResetAction? _backendPasswordReset;
  final EmailPasswordResetAction? _nativePasswordReset;
  final EmailPasswordResetAction _defaultBackendPasswordReset;
  final EmailVerificationAction? _requestEmailVerification;
  final EmailVerificationAction _defaultRequestEmailVerification;
  final EmailVerificationSyncAction? _syncEmailVerification;
  final EmailVerificationSyncAction _defaultSyncEmailVerification;
  final AuthenticatedUserCheck? _hasCurrentUser;
  final EnsureSignedInUserProfileAction? _ensureSignedInUserProfile;
  final EnsureSignedInUserProfileAction _defaultEnsureSignedInUserProfile;
  final EnsureEmailUserProfileAction? _ensureEmailUserProfile;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;
  AuthUserProfileService get _resolvedProfileService =>
      _profileService ?? _profileServiceFactory();

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _resolvedAuth;
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user ?? auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-token-expired',
        message: 'Session Firebase introuvable après connexion.',
      );
    }

    final ensureProfile = _ensureSignedInUserProfile;
    if (ensureProfile != null) {
      await ensureProfile(
        user: user,
        authMethod: 'email',
        isNewUserHint: false,
      );
    } else {
      await _defaultEnsureSignedInUserProfile(
        user: user,
        authMethod: 'email',
        isNewUserHint: false,
      );
    }
    return user;
  }

  Future<User> register({
    required String displayName,
    required String email,
    required String password,
    bool createBusinessProfile = false,
  }) async {
    final auth = _resolvedAuth;
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user ?? auth.currentUser;
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

    final refreshedUser = auth.currentUser ?? user;
    final ensureProfile = _ensureEmailUserProfile;
    if (ensureProfile != null) {
      await ensureProfile(
        user: refreshedUser,
        displayName: normalizedDisplayName,
        isBusinessAccount: createBusinessProfile,
      );
    } else {
      await _resolvedProfileService.ensureEmailUserProfile(
        user: refreshedUser,
        displayName: normalizedDisplayName,
        isBusinessAccount: createBusinessProfile,
      );
    }
    await _runEmailVerificationRequest();
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
      final backendReset = _backendPasswordReset;
      if (backendReset != null) {
        await backendReset(normalizedEmail);
      } else {
        await _defaultBackendPasswordReset(normalizedEmail);
      }
    } catch (_) {
      final nativeReset = _nativePasswordReset;
      if (nativeReset != null) {
        await nativeReset(normalizedEmail);
      } else {
        await _resolvedAuth.sendPasswordResetEmail(email: normalizedEmail);
      }
    }
  }

  Future<void> requestEmailVerificationEmail() async {
    final hasCurrentUser =
        _hasCurrentUser?.call() ?? _resolvedAuth.currentUser != null;
    if (!hasCurrentUser) {
      throw FirebaseAuthException(
        code: 'user-token-expired',
        message: 'Reconnecte-toi pour recevoir un email de vérification.',
      );
    }
    await _runEmailVerificationRequest();
  }

  Future<bool> syncCurrentUserEmailVerificationState() {
    final sync = _syncEmailVerification;
    if (sync != null) return sync();
    return _defaultSyncEmailVerification();
  }

  Future<void> _runEmailVerificationRequest() {
    final request = _requestEmailVerification;
    if (request != null) return request();
    return _defaultRequestEmailVerification();
  }
}
