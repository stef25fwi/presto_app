import 'package:firebase_auth/firebase_auth.dart';

abstract final class AuthErrorMapper {
  static String message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Cette adresse email est déjà associée à un compte.';
        case 'invalid-email':
          return 'Adresse email invalide.';
        case 'weak-password':
          return 'Mot de passe trop faible. Utilise au moins 8 caractères avec lettres et chiffres.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email ou mot de passe incorrect.';
        case 'user-not-found':
          return 'Email ou mot de passe incorrect.';
        case 'user-disabled':
          return 'Ce compte a été désactivé.';
        case 'too-many-requests':
          return 'Trop de tentatives. Réessaie dans quelques minutes.';
        case 'network-request-failed':
          return 'Problème réseau. Vérifie ta connexion internet.';
        case 'requires-recent-login':
          return 'Pour cette action sensible, reconnecte-toi puis réessaie.';
        case 'credential-already-in-use':
          return 'Ce moyen de connexion est déjà utilisé par un autre compte.';
        case 'operation-not-allowed':
          return 'Cette méthode de connexion n’est pas encore activée.';
        default:
          return 'Erreur d’authentification : ${error.code}';
      }
    }

    return 'Une erreur est survenue. Réessaie.';
  }
}
