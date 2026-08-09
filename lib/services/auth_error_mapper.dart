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
          return 'Trop de tentatives Firebase ont été détectées. Réessaie dans quelques minutes.';
        case 'network-request-failed':
          return 'Problème réseau. Vérifie ta connexion internet puis réessaie.';
        case 'requires-recent-login':
          return 'Pour cette action sensible, reconnecte-toi puis réessaie.';
        case 'credential-already-in-use':
          return 'Ce moyen de connexion est déjà utilisé par un autre compte.';
        case 'operation-not-allowed':
          return 'La vérification par téléphone n’est pas autorisée par la configuration Firebase. Vérifie le provider Téléphone et la règle des régions SMS.';
        case 'invalid-phone-number':
          return 'Numéro de téléphone invalide. Vérifie l’indicatif et le format international.';
        case 'app-not-authorized':
          return 'Cette application n’est pas autorisée à utiliser Firebase Phone Auth. Vérifie la configuration Android/iOS et les empreintes de l’application.';
        case 'captcha-check-failed':
          return 'La vérification anti-abus Firebase a échoué. Relance la vérification et termine le contrôle de sécurité si Firebase le demande.';
        case 'missing-app-credential':
        case 'invalid-app-credential':
          return 'Firebase n’a pas pu valider l’authenticité de l’application pour l’envoi du SMS. Vérifie App Check, Play Integrity/APNs et la configuration Phone Auth.';
        case 'missing-client-identifier':
          return 'Firebase n’a pas pu identifier correctement cet appareil pour la vérification par SMS.';
        case 'web-context-cancelled':
          return 'La vérification de sécurité Firebase a été annulée avant l’envoi du SMS.';
        case 'web-context-already-present':
          return 'Une vérification Firebase est déjà en cours. Termine-la ou ferme-la avant de recommencer.';
        case 'phone-verification-timeout':
          return 'Firebase n’a pas confirmé l’envoi du SMS dans le délai prévu. Réessaie après vérification de la configuration Phone Auth et de la connexion réseau.';
        case 'phone-verification-start-failed':
          return 'Firebase Phone Auth n’a pas pu démarrer. Réessaie après vérification de la configuration de l’application.';
        case 'invalid-verification-code':
          return 'Code incorrect. Vérifie les chiffres reçus par SMS.';
        case 'invalid-verification-id':
        case 'session-expired':
          return 'La demande a expiré. Renvoie un nouveau code.';
        case 'missing-verification-code':
          return 'Saisis le code reçu par SMS.';
        case 'quota-exceeded':
          return 'Le quota d’envoi SMS Firebase est atteint. Réessaie plus tard.';
        default:
          return 'Erreur d’authentification Firebase : ${error.code}';
      }
    }

    return 'Une erreur est survenue. Réessaie.';
  }
}
