import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/l10n/app_localizations_fr.dart';

void main() {
  group('AppLocalizationsFr', () {
    test('expose tous les libellés français', () {
      final l10n = AppLocalizationsFr();

      expect(l10n.localeName, 'fr');
      expect(
        <String>[
          l10n.appName,
          l10n.commonSave,
          l10n.commonCancel,
          l10n.commonDelete,
          l10n.commonRetry,
          l10n.commonClose,
          l10n.commonContinue,
          l10n.commonBack,
          l10n.commonLoading,
          l10n.languageTitle,
          l10n.languageSystem,
          l10n.languageFrench,
          l10n.languageEnglish,
          l10n.languageSpanish,
          l10n.languageChanged,
          l10n.errorGeneric,
          l10n.errorNetworkUnavailable,
          l10n.errorUserNotFound,
          l10n.errorPaymentFailed,
        ],
        <String>[
          'iliprestō',
          'Enregistrer',
          'Annuler',
          'Supprimer',
          'Réessayer',
          'Fermer',
          'Continuer',
          'Retour',
          'Chargement…',
          'Langue de l’application',
          'Automatique — langue de l’appareil',
          'Français',
          'English',
          'Español',
          'La langue de l’application a été mise à jour.',
          'Une erreur est survenue. Veuillez réessayer.',
          'Connexion indisponible. Vérifiez votre accès à Internet.',
          'Utilisateur introuvable.',
          'Le paiement a échoué. Aucun débit n’a été confirmé.',
        ],
      );
    });

    test('formate les compteurs et notifications', () {
      final l10n = AppLocalizationsFr('fr_FR');

      expect(l10n.localeName, 'fr_FR');
      expect(l10n.offerResultsCount(0), 'Aucune annonce');
      expect(l10n.offerResultsCount(1), '1 annonce');
      expect(l10n.offerResultsCount(7), '7 annonces');
      expect(
        l10n.notificationNewMessage('Sofia'),
        'Nouveau message de Sofia',
      );
    });
  });
}
