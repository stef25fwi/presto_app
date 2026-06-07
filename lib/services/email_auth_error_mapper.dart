import 'package:firebase_auth/firebase_auth.dart';

String mapEmailAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-not-found':
        return 'Aucun compte ne correspond à cet email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email.';
      case 'weak-password':
        return 'Le mot de passe doit contenir au moins 6 caractères.';
      case 'missing-password':
        return 'Le mot de passe est obligatoire.';
      case 'missing-email':
        return 'L’adresse email est obligatoire.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessaie plus tard.';
      case 'network-request-failed':
        return 'Connexion internet indisponible. Vérifie ton réseau.';
      case 'operation-not-allowed':
        return 'Connexion email non activée dans Firebase Authentication.';
      case 'requires-recent-login':
        return 'Reconnecte-toi pour effectuer cette action.';
      case 'unauthorized-domain':
        return 'Domaine non autorisé dans Firebase Authentication.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return 'Erreur Firebase Auth : ${error.code}.';
    }
  }

  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return 'Erreur inconnue.';
  }
  return raw.replaceFirst('Exception: ', '');
}

String mapPasswordResetSuccessMessage(String email) {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Si un compte existe, un email de réinitialisation a été envoyé.';
  }
  return 'Email de réinitialisation envoyé à $normalized.';
}

String mapEmailVerificationSuccessMessage() {
  return 'Email de vérification envoyé. Vérifie ta boîte mail.';
}
