import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/app_check_state.dart';

/// Service centralisé pour Google Sign-In avec gestion d'erreurs améliorée
class GoogleAuthService {
  // final _auth = FirebaseAuth.instance; // Unused for now

  // Configuration
  static const int maxRetries = 2;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Message d'erreur utilisateur-friendly en français
  String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getFirebaseErrorMessage(error.code, error.message);
    }
    if (error is PlatformException) {
      return _getPlatformErrorMessage(error.code, error.message);
    }
    return "Erreur inattendue. Réessaye.";
  }

  bool _isLikelyUserAbortedGoogleFlow(String? message) {
    final msg = (message ?? '').toLowerCase();
    return msg.contains(
            'there was an error while trying to get your package certificate hash') ||
        msg.contains('package certificate hash');
  }

  /// Vrai si le code + message indiquent un blocage par App Check enforcement.
  /// Firebase Auth renvoie 'internal-error' avec des messages serveur spécifiques
  /// (INVALID_APP_CREDENTIAL, REQUEST_BLOCKED) quand App Check est en mode enforced.
  bool _isLikelyAppCheckEnforcement(String code, String? message) {
    if (code != 'internal-error') return false;
    final msg = (message ?? '').toLowerCase();
    if (msg.contains('invalid_app_credential') ||
        msg.contains('app_credential') ||
        msg.contains('app check') ||
        msg.contains('appcheck') ||
        msg.contains('request_blocked')) {
      return true;
    }
    // Heuristique: si App Check a échoué à l'activation ET qu'on reçoit
    // internal-error, App Check est très probablement la cause.
    return appCheckActivationAttempted && !appCheckActivationSucceeded;
  }

  /// Version publique utilisée dans shouldFallbackToRedirect.
  bool isLikelyAppCheckEnforcement(dynamic error) {
    if (error is! FirebaseAuthException) return false;
    return _isLikelyAppCheckEnforcement(error.code, error.message);
  }

  /// Messages FirebaseAuthException
  String _getFirebaseErrorMessage(String code, String? message) {
    switch (code) {
      // Erreurs OAuth2
      case 'internal-error':
        if (_isLikelyAppCheckEnforcement(code, message)) {
          return "🔒 Vérification de sécurité incomplète. "
              "Réessaie dans quelques secondes ou essaie un autre navigateur.";
        }
        return "❌ La fenêtre Google n'a pas pu s'ouvrir. "
            "Autorise les pop-ups pour ce site, puis réessaie.";
      case 'auth-error':
        return "❌ Erreur d'authentification. "
            "Vérifie que Google Sign-In est activé dans Firebase Console.";
      case 'invalid-oauth-client':
        return "❌ Erreur de configuration OAuth. "
            "Ton Client ID Google est invalide ou non configuré.";
      case 'idp-error':
        return "❌ Erreur du fournisseur d'identité (Google). "
            "Les serveurs Google ont un problème. Réessaye dans quelques instants.";

      // Domaine / Popup
      case 'unauthorized-domain':
        return "❌ Domaine non autorisé. "
            "Admin: Ajoute ce domaine dans Firebase Console → Authentication → Authorized domains";
      case 'operation-not-allowed':
        return "❌ Google Sign-In désactivé. "
            "Admin: Active-le dans Firebase Console → Authentication → Sign-in method → Google";
      case 'popup-blocked':
        return "⚠️ Pop-up bloquée. Autorise les pop-ups pour ce site et réessaye.";
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'cancelled':
        return ''; // Annulation silencieuse
      case 'network-request-failed':
        return "📡 Erreur réseau. Vérifie ta connexion internet et réessaye.";

      // Credentials
      case 'account-exists-with-different-credential':
        return "⚠️ Ce compte existe déjà avec une autre méthode. "
            "Utilise la même méthode (email/Google/Apple).";
      case 'invalid-credential':
        return "⚠️ Identifiants invalides. Réessaye avec un autre compte.";
      case 'user-disabled':
        return "🔒 Ce compte a été désactivé. Contacte le support.";
      case 'user-not-found':
        return "⚠️ Aucun compte trouvé. Crée-toi un compte d'abord.";
      case 'wrong-password':
        return "⚠️ Mot de passe incorrect.";
      case 'invalid-email':
        return "⚠️ Email invalide.";

      // Default
      default:
        return "❌ Erreur: ${message ?? code}";
    }
  }

  /// Messages PlatformException (Google Sign-In mobile)
  String _getPlatformErrorMessage(String code, String? message) {
    if (_isLikelyUserAbortedGoogleFlow(message)) {
      return 'Connexion Google interrompue. Vous pouvez réessayer quand vous voulez.';
    }

    switch (code) {
      case 'sign_in_canceled':
      case 'sign_in_cancelled':
        return ''; // Annulation silencieuse
      case 'network_error':
        return "📡 Erreur réseau. Vérifie ta connexion et réessaye.";
      case 'sign_in_failed':
        return "⚠️ Connexion échouée. Vérifie tes identifiants.";
      case 'google_sign_in_failed':
        return "❌ Erreur Google Sign-In. Réessaye.";
      case 'missing_google_play_services':
        return "📱 Google Play Services manquant. Mets-le à jour.";
      default:
        return "❌ Erreur: ${message ?? code}";
    }
  }

  /// Heuristique pour déterminer si on doit faire un retry
  bool shouldRetry(dynamic error) {
    if (error is FirebaseAuthException) {
      // Retry sur erreurs temporaires/réseau
      return error.code == 'network-request-failed' ||
          error.code == 'internal-error' ||
          error.code == 'idp-error';
    }
    if (error is PlatformException) {
      return error.code == 'network_error';
    }
    return false;
  }

  /// Heuristique pour fallback popup → redirect.
  ///
  /// Ne déclenche le fallback QUE pour les vrais blocages browser (popup
  /// refusée par le navigateur, COOP/COEP). Les annulations volontaires
  /// utilisateur (`popup-closed-by-user`, `cancelled-popup-request`) ne
  /// doivent PAS déclencher un redirect, sinon on relance un flux complet
  /// avec rechargement de page alors que l'utilisateur a juste fermé le
  /// popup.
  bool shouldFallbackToRedirect(dynamic error) {
    // App Check enforcement produit aussi internal-error — le redirect
    // échouerait de la même façon. Ne pas boucler.
    if (isLikelyAppCheckEnforcement(error)) return false;

    final msg = error.toString().toLowerCase();
    final hasCoopSignal = msg.contains('cross-origin-opener-policy') ||
        msg.contains('cross-origin');
    final hasPopupBlockedSignal = msg.contains('popup-blocked') ||
        msg.contains('popup blocked') ||
        msg.contains('popup-blocked-by-browser');

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'popup-blocked':
        case 'popup-blocked-by-browser':
          return true;
        // internal-error est trop générique (App Check, OAuth mal configuré,
        // réseau…). Déclencher un redirect sur cette erreur provoque un
        // rechargement de page/splash sans popup visible. On affiche un
        // message d'erreur à la place.
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'cancelled':
        case 'user-cancelled':
          return false;
        case 'internal-error':
          // Rétablit le flow redirect uniquement quand les signaux indiquent
          // un vrai blocage navigateur (COOP/popup), pas pour les erreurs
          // OAuth/App Check génériques.
          return hasCoopSignal || hasPopupBlockedSignal;
        default:
          break;
      }
    }

    if (msg.contains('closed-by-user') ||
        msg.contains('cancelled-popup-request') ||
        msg.contains('cancelled') ||
        msg.contains('canceled')) {
      return false;
    }

    if (msg.contains('internal-error')) {
      return hasCoopSignal || hasPopupBlockedSignal;
    }

    return hasPopupBlockedSignal || hasCoopSignal;
  }

  /// Vrai si l'erreur correspond à une annulation volontaire de l'utilisateur
  /// (popup fermée, demande annulée). On peut alors afficher un message
  /// neutre sans relancer de redirect.
  bool isUserCancelled(dynamic error) {
    if (error is FirebaseAuthException) {
      return error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.code == 'cancelled' ||
          error.code == 'user-cancelled';
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('closed-by-user') ||
        msg.contains('cancelled-popup-request');
  }

  /// Log détaillé pour débugage
  void logError(String method, dynamic error, {int? retryCount}) {
    final timestamp = DateTime.now().toIso8601String();
    final retry = retryCount != null ? ' [Retry $retryCount/$maxRetries]' : '';

    debugPrint('');
    debugPrint('❌ [Google Auth] $method $retry @ $timestamp');
    debugPrint('   Error type: ${error.runtimeType}');

    if (error is FirebaseAuthException) {
      debugPrint('   Code: ${error.code}');
      debugPrint('   Message: ${error.message}');
    } else if (error is PlatformException) {
      debugPrint('   Code: ${error.code}');
      debugPrint('   Message: ${error.message}');
    } else {
      debugPrint('   Details: $error');
    }
    debugPrint('');
  }

  /// Log de succès
  void logSuccess(String method, String? email) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('✅ [Google Auth] $method réussi @ $timestamp');
    if (email != null) {
      debugPrint('   Email: $email');
    }
    debugPrint('');
  }

  /// Log de tentative
  void logAttempt(String method, {String? details}) {
    debugPrint('🔄 [Google Auth] $method...');
    if (details != null) {
      debugPrint('   $details');
    }
  }

  /// Log fallback
  void logFallback(String from, String to, {String? reason}) {
    debugPrint('⚠️ [Google Auth] Fallback: $from → $to');
    if (reason != null) {
      debugPrint('   Raison: $reason');
    }
  }
}

/// Extension pour afficher messages sans null
extension NullableStringExt on String? {
  bool get isNotEmpty => this != null && this!.isNotEmpty;

  /// Affiche le message si non-null, sinon silencieux
  void showIfNotNull(Function(String) onShow) {
    if (this != null && this!.isNotEmpty) {
      onShow(this!);
    }
  }
}
