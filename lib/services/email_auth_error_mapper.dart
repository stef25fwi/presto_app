String friendlyEmailAuthErrorMessage(String code, [String? fallbackMessage]) {
  switch (code) {
    case 'invalid-email':
      return 'Adresse e-mail invalide.';
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
      return fallbackMessage ?? 'Erreur d\'authentification.';
  }
}
