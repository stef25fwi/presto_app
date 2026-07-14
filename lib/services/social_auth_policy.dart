import 'package:firebase_auth/firebase_auth.dart';

class SocialAuthPolicy {
  const SocialAuthPolicy._();

  static bool shouldFallbackToRedirect(Object error) {
    final message = error.toString().toLowerCase();
    final hasCoopSignal = message.contains('cross-origin-opener-policy') ||
        message.contains('cross-origin');
    final hasPopupBlockedSignal = message.contains('popup-blocked') ||
        message.contains('popup blocked') ||
        message.contains('popup-blocked-by-browser');

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'popup-blocked':
        case 'popup-blocked-by-browser':
          return true;
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'cancelled':
        case 'user-cancelled':
          return false;
        case 'internal-error':
          return hasCoopSignal || hasPopupBlockedSignal;
      }
    }

    if (message.contains('closed-by-user') ||
        message.contains('cancelled-popup-request') ||
        message.contains('cancelled') ||
        message.contains('canceled')) {
      return false;
    }

    if (message.contains('internal-error')) {
      return hasCoopSignal || hasPopupBlockedSignal;
    }

    return hasPopupBlockedSignal || hasCoopSignal;
  }

  static String facebookErrorMessage(Object error) {
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
}
