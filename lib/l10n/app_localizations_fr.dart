// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'iliprestō';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get languageTitle => 'Langue de l’application';

  @override
  String get languageSystem => 'Automatique — langue de l’appareil';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageChanged => 'La langue de l’application a été mise à jour.';

  @override
  String get errorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get errorNetworkUnavailable =>
      'Connexion indisponible. Vérifiez votre accès à Internet.';

  @override
  String get errorUserNotFound => 'Utilisateur introuvable.';

  @override
  String get errorPaymentFailed =>
      'Le paiement a échoué. Aucun débit n’a été confirmé.';

  @override
  String offerResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count annonces',
      one: '1 annonce',
      zero: 'Aucune annonce',
    );
    return '$_temp0';
  }

  @override
  String notificationNewMessage(String senderName) {
    return 'Nouveau message de $senderName';
  }
}
