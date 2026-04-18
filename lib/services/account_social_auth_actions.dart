import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/google_auth_service.dart';
import '../services/user_profile_bootstrap_service.dart';
import '../utils/friendly_snackbar.dart';

typedef AccountTrackLoginCallback = Future<void> Function({
  String? authMethod,
  bool isNewUser,
});

class AccountSocialAuthActions {
  static Future<void> signInWithGoogle({
    required BuildContext context,
    required FirebaseAuth auth,
    required GoogleAuthService googleAuthService,
    required AccountTrackLoginCallback trackLogin,
  }) async {
    try {
      bool isNewUser = false;
      googleAuthService.logAttempt(
        'signInWithGoogle',
        details: kIsWeb ? 'Mode Web' : 'Mode Mobile',
      );

      if (kIsWeb) {
        final googleProvider = _buildGoogleProvider(forceAccountSelection: true);

        try {
          googleAuthService.logAttempt('Popup');
          final popupResult = await auth.signInWithPopup(googleProvider);
          isNewUser = popupResult.additionalUserInfo?.isNewUser ?? false;
          googleAuthService.logSuccess('Popup', auth.currentUser?.email);

          // Cas Safari/COOP: signInWithPopup peut retourner un UserCredential
          // sans user à cause des restrictions Cross-Origin-Opener-Policy,
          // alors que la session Firebase est bien établie côté backend. On
          // attend explicitement un événement authStateChanges avant de
          // conclure à un échec.
          if (popupResult.user == null && auth.currentUser == null) {
            try {
              await auth
                  .authStateChanges()
                  .firstWhere((u) => u != null)
                  .timeout(const Duration(seconds: 3));
            } on TimeoutException {
              googleAuthService.logError(
                'Popup',
                'UserCredential vide et aucun authStateChanges en 3s',
              );
            }
          }
        } catch (popupError) {
          googleAuthService.logError('Popup', popupError);

          // Annulation volontaire utilisateur: pas de fallback redirect,
          // juste un message neutre. Évite de relancer un flux complet
          // avec rechargement de page après que l'utilisateur a fermé le
          // popup.
          if (googleAuthService.isUserCancelled(popupError)) {
            if (!context.mounted) return;
            showErrorSnackBar(context, 'Connexion annulée.');
            return;
          }

          if (googleAuthService.shouldFallbackToRedirect(popupError)) {
            try {
              googleAuthService.logFallback(
                'Popup',
                'Redirect',
                reason: 'Popup bloqué par le navigateur',
              );
              await auth.signInWithRedirect(googleProvider);
              return;
            } catch (redirectError) {
              googleAuthService.logError('Redirect', redirectError);
              if (!context.mounted) return;

              final msg = googleAuthService.getErrorMessage(redirectError);
              if (msg.isNotEmpty) {
                showErrorSnackBar(context, msg);
              }
              return;
            }
          }

          if (!context.mounted) return;

          final msg = googleAuthService.getErrorMessage(popupError);
          if (msg.isNotEmpty) {
            showErrorSnackBar(context, msg);
          }
          return;
        }
      } else {
        final provider = _buildGoogleProvider(forceAccountSelection: true);

        googleAuthService.logAttempt('signInWithProvider');
        final providerResult = await auth.signInWithProvider(provider);
        isNewUser = providerResult.additionalUserInfo?.isNewUser ?? false;
        googleAuthService.logSuccess('Provider', auth.currentUser?.email);
      }

      final user = auth.currentUser;
      bool bootstrapFailed = false;
      if (user == null) {
        if (!context.mounted) return;
        showErrorSnackBar(context, 'Connexion Google incomplete. Reessayez.');
        return;
      }
      try {
        await UserProfileBootstrapService.ensureUserDocument(
          user: user,
          authMethod: 'google',
          isNewUserHint: isNewUser,
        );
      } catch (bootstrapError) {
        bootstrapFailed = true;
        googleAuthService.logError('AuthBootstrap', bootstrapError);
      }
      try {
        await trackLogin(authMethod: 'google', isNewUser: isNewUser);
      } catch (trackingError) {
        googleAuthService.logError('Tracking', trackingError);
      }

      if (!context.mounted) return;
      googleAuthService.logSuccess('signInWithGoogle', user.email);
      if (bootstrapFailed) {
        showSuccessSnackBar(context, 'Connecté, profil en cours de création…');
      } else {
        showSuccessSnackBar(context, '✓ Connecté avec Google');
      }
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        '❌ FirebaseAuthException: code=${e.code} message=${e.message}',
      );
      debugPrintStack(stackTrace: st);
      googleAuthService.logError('signInWithGoogle', e);
      if (!context.mounted) return;

      final msg = googleAuthService.getErrorMessage(e);
      if (msg.isNotEmpty) {
        showErrorSnackBar(context, msg);
      }
    } on PlatformException catch (e, st) {
      debugPrint('❌ PlatformException: code=${e.code} message=${e.message}');
      debugPrintStack(stackTrace: st);
      googleAuthService.logError('signInWithGoogle', e);
      if (!context.mounted) return;

      final msg = googleAuthService.getErrorMessage(e);
      if (msg.isNotEmpty) {
        showErrorSnackBar(context, msg);
      }
    } catch (e, stackTrace) {
      googleAuthService.logError('signInWithGoogle', e);
      debugPrint('Stack trace: $stackTrace');
      if (!context.mounted) return;
      showErrorSnackBar(context, 'Erreur lors de la connexion. Réessaye.');
    }
  }

  static Future<void> signInWithFacebook({
    required BuildContext context,
    required FirebaseAuth auth,
    required AccountTrackLoginCallback trackLogin,
  }) async {
    final provider = FacebookAuthProvider()
      ..setCustomParameters(<String, String>{
        'display': 'popup',
      })
      ..addScope('email')
      ..addScope('public_profile');

    try {
      bool isNewUser = false;

      if (kIsWeb) {
        try {
          final popupResult = await auth.signInWithPopup(provider);
          isNewUser = popupResult.additionalUserInfo?.isNewUser ?? false;
        } catch (popupError) {
          if (_shouldFallbackToRedirect(popupError)) {
            await auth.signInWithRedirect(provider);
            return;
          }
          if (!context.mounted) return;
          showErrorSnackBar(context, _facebookErrorMessage(popupError));
          return;
        }
      } else {
        final providerResult = await auth.signInWithProvider(provider);
        isNewUser = providerResult.additionalUserInfo?.isNewUser ?? false;
      }

      if (!context.mounted) return;
      await _finalizeSocialSignIn(
        context: context,
        auth: auth,
        authMethod: 'facebook',
        providerLabel: 'Facebook',
        isNewUser: isNewUser,
        trackLogin: trackLogin,
      );
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      showErrorSnackBar(context, _facebookErrorMessage(error));
    } catch (error) {
      if (!context.mounted) return;
      showErrorSnackBar(
        context,
        'Erreur lors de la connexion Facebook. Reessayez.',
      );
    }
  }

  static Future<void> signInWithApple({
    required BuildContext context,
    required FirebaseAuth auth,
    required AccountTrackLoginCallback trackLogin,
  }) async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      if (!context.mounted) return;
      showErrorSnackBar(
        context,
        'Connexion Apple disponible uniquement sur iOS et macOS.',
      );
      return;
    }

    try {
      debugPrint('[Apple Sign-In] Démarrage de l\'authentification Apple...');
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      debugPrint(
        '[Apple Sign-In] Credentials reçus: ${appleCredential.identityToken != null}',
      );

      if (appleCredential.identityToken == null) {
        throw Exception('Identité Apple non reçue');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      final userCredential = await auth.signInWithCredential(oauthCredential);
      debugPrint(
        '[Apple Sign-In] Utilisateur connecté: ${userCredential.user?.uid}',
      );

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final fullName = appleCredential.givenName != null ||
                appleCredential.familyName != null
            ? '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim()
            : null;

        if (fullName != null && fullName.isNotEmpty) {
          try {
            await userCredential.user?.updateDisplayName(fullName);
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user?.uid)
                .set({'pseudo': fullName}, SetOptions(merge: true));
            debugPrint('[Apple Sign-In] Nom mis à jour: $fullName');
          } catch (e) {
            debugPrint('[Apple Sign-In] Erreur mise à jour nom: $e');
          }
        }
      }

      final user = auth.currentUser;
      bool bootstrapFailed = false;
      if (user != null) {
        try {
          await UserProfileBootstrapService.ensureUserDocument(
            user: user,
            authMethod: 'apple',
            isNewUserHint: isNewUser,
          );
        } catch (bootstrapError) {
          bootstrapFailed = true;
          debugPrint('[Apple Sign-In] Auth bootstrap error: $bootstrapError');
        }
      }
      await trackLogin(authMethod: 'apple', isNewUser: isNewUser);

      if (!context.mounted) return;
      if (bootstrapFailed) {
        showSuccessSnackBar(context, 'Connecte, profil en cours de creation…');
      } else {
        showSuccessSnackBar(context, 'Connecte avec Apple ✓');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!context.mounted) return;
      debugPrint(
        '[Apple Sign-In] Authorization error: ${e.code} - ${e.message}',
      );

      String msg;
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          msg = 'Connexion Apple annulée.';
          break;
        case AuthorizationErrorCode.credentialExport:
          msg = 'Export des identifiants Apple non pris en charge sur cet appareil.';
          break;
        case AuthorizationErrorCode.credentialImport:
          msg = 'Import des identifiants Apple non pris en charge sur cet appareil.';
          break;
        case AuthorizationErrorCode.failed:
          msg = 'Échec de l\'authentification Apple. Réessaye.';
          break;
        case AuthorizationErrorCode.invalidResponse:
          msg = 'Réponse Apple invalide. Contacte le support.';
          break;
        case AuthorizationErrorCode.notHandled:
          msg = 'Requête Apple non traitée.';
          break;
        case AuthorizationErrorCode.notInteractive:
          msg = 'Authentification Apple non disponible en arrière-plan.';
          break;
        case AuthorizationErrorCode.unknown:
          msg = 'Erreur Apple inconnue. Réessaye.';
          break;
        default:
          msg = 'Erreur Apple inattendue. Réessaye.';
          break;
      }
      showErrorSnackBar(context, msg);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      debugPrint('[Apple Sign-In] Firebase error: ${e.code} - ${e.message}');

      String msg;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          msg =
              'Un compte existe déjà avec cet email. Utilise ta méthode de connexion habituelle.';
          break;
        case 'invalid-credential':
          msg = 'Credentials Apple invalides. Réessaye.';
          break;
        case 'operation-not-allowed':
          msg = 'Connexion Apple non activée. Contacte le support.';
          break;
        case 'user-disabled':
          msg = 'Ce compte a été désactivé.';
          break;
        case 'user-not-found':
          msg = 'Aucun compte trouvé. Un nouveau compte sera créé.';
          break;
        case 'invalid-verification-code':
        case 'invalid-verification-id':
          msg = 'Code de vérification Apple invalide.';
          break;
        default:
          msg = 'Erreur Firebase : ${e.message ?? e.code}';
      }
      showErrorSnackBar(context, msg);
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('[Apple Sign-In] Unexpected error: $e');
      showErrorSnackBar(context, 'Erreur inattendue : $e');
    }
  }

  static Future<void> _finalizeSocialSignIn({
    required BuildContext context,
    required FirebaseAuth auth,
    required String authMethod,
    required String providerLabel,
    required bool isNewUser,
    required AccountTrackLoginCallback trackLogin,
  }) async {
    final user = auth.currentUser;
    bool bootstrapFailed = false;

    if (user == null) {
      if (!context.mounted) return;
      showErrorSnackBar(
        context,
        'Connexion $providerLabel incomplete. Reessayez.',
      );
      return;
    }

    try {
      await UserProfileBootstrapService.ensureUserDocument(
        user: user,
        authMethod: authMethod,
        isNewUserHint: isNewUser,
      );
    } catch (bootstrapError) {
      bootstrapFailed = true;
      debugPrint('[$providerLabel Sign-In] Auth bootstrap error: $bootstrapError');
    }

    try {
      await trackLogin(authMethod: authMethod, isNewUser: isNewUser);
    } catch (trackingError) {
      debugPrint('[$providerLabel Sign-In] Tracking error: $trackingError');
    }

    if (!context.mounted) return;
    if (bootstrapFailed) {
      showSuccessSnackBar(context, 'Connecté, profil en cours de création…');
    } else {
      showSuccessSnackBar(context, '✓ Connecté avec $providerLabel');
    }
  }

  static bool _shouldFallbackToRedirect(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('popup') ||
        message.contains('blocked') ||
        message.contains('cross-origin') ||
        message.contains('internal-error');
  }

  static String _facebookErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
          return 'Un compte existe déjà avec cet email. Utilise ta méthode de connexion habituelle.';
        case 'popup-blocked':
          return 'Pop-up Facebook bloquée. Autorise les pop-ups puis réessaie.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'cancelled':
          return '';
        case 'operation-not-allowed':
          return 'Connexion Facebook non activée dans Firebase Authentication.';
        case 'invalid-credential':
          return 'Identifiants Facebook invalides. Réessaie.';
        case 'network-request-failed':
          return 'Erreur réseau. Vérifie la connexion internet.';
      }
      return error.message ?? 'Erreur de connexion Facebook.';
    }
    return 'Erreur de connexion Facebook. Reessayez.';
  }

  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static GoogleAuthProvider _buildGoogleProvider({
    bool forceAccountSelection = false,
  }) {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');

    final customParameters = <String, String>{
      'prompt': forceAccountSelection ? 'select_account consent' : 'select_account',
    };

    if (forceAccountSelection) {
      customParameters['authuser'] = '-1';
      customParameters['login_hint'] = '';
      customParameters['include_granted_scopes'] = 'false';
    }

    provider.setCustomParameters(customParameters);
    return provider;
  }
}
