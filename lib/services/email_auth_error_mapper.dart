String friendlyEmailAuthErrorMessage(String code, [String? fallbackMessage]) {
  switch (code) {
    case 'invalid-email':
      return 'Adresse e-mail invalide.';
    case 'user-disabled':
      return 'Ce compte a ete desactive.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'E-mail ou mot de passe incorrect.';
    case 'email-already-in-use':
    case 'credential-already-in-use':
    case 'account-exists-with-different-credential':
      return 'Un compte existe deja avec cet e-mail.';
    case 'weak-password':
      return 'Mot de passe trop faible (minimum 6 caracteres).';
    case 'too-many-requests':
      return 'Trop de tentatives. Reessayez dans quelques minutes.';
    case 'network-request-failed':
      return 'Erreur reseau. Verifiez votre connexion internet.';
    case 'operation-not-allowed':
      return 'Connexion e-mail non activee dans Firebase Authentication.';
    case 'requires-recent-login':
      return 'Cette action nécessite une reconnexion récente.';
    case 'user-token-expired':
      return 'Votre session a expiré. Reconnectez-vous.';
    case 'unverified-email':
      return 'Veuillez vérifier votre adresse e-mail avant de continuer.';
    case 'app-check-token-is-invalid':
      return "Verification de securite echouee. Actualisez l'application et reessayez.";
    default:
      return fallbackMessage ?? 'Erreur d\'authentification.';
  }
}