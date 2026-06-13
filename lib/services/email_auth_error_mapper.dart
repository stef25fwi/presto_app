import 'package:firebase_auth/firebase_auth.dart';

String friendlyEmailAuthErrorMessage(String code, [String? fallbackMessage]) {
  switch (code.trim()) {
    case 'invalid-email':
      return 'Adresse e-mail invalide.';
    case ‘missing-email’:
      return "L’adresse e-mail est obligatoire.";
    case 'missing-password':
      return 'Le mot de passe est obligatoire.';
    case 'user-disabled':
      return 'Ce compte a été désactivé.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'E-mail ou mot de passe incorrect.';
    case 'email-already-in-use':
    case 'credential-already-in-use':
    case 'account-exists-with-different-credential':
      return 'Un compte existe déjà avec cet e-mail.';
    case 'weak-password':
      return 'Mot de passe trop faible (minimum 8 caractères).';
    case 'too-many-requests':
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    case 'network-request-failed':
      return 'Erreur réseau. Vérifiez votre connexion internet.';
    case 'operation-not-allowed':
      return 'Connexion e-mail non activée dans Firebase Authentication.';
    case 'requires-recent-login':
      return 'Cette action nécessite une reconnexion récente.';
    case 'user-token-expired':
      return 'Votre session a expiré. Reconnectez-vous.';
    case 'unverified-email':
      return 'Veuillez vérifier votre adresse e-mail avant de continuer.';
    case 'app-check-token-is-invalid':
      return "Vérification de sécurité échouée. Actualisez l'application et réessayez.";
    default:
      final fallback = fallbackMessage?.trim();
      return fallback == null || fallback.isEmpty
          ? "Erreur d’authentification."
          : fallback;
  }
}

String mapEmailAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return friendlyEmailAuthErrorMessage(error.code, error.message);
  }

  final raw = error.toString().replaceFirst(‘Exception: ‘, ‘’).trim();
  return raw.isEmpty ? "Erreur d’authentification." : raw;
}

String mapPasswordResetSuccessMessage(String email) {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Si un compte existe, un e-mail de réinitialisation a été envoyé.';
  }
  return 'E-mail de réinitialisation envoyé à $normalized.';
}

String mapEmailVerificationSuccessMessage() {
  return 'E-mail de vérification envoyé. Vérifie ta boîte mail.';
}
