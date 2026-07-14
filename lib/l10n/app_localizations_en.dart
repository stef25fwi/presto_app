// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'iliprestō';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonBack => 'Back';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get languageTitle => 'App language';

  @override
  String get languageSystem => 'Automatic — device language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageChanged => 'The app language has been updated.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetworkUnavailable =>
      'Connection unavailable. Check your internet access.';

  @override
  String get errorUserNotFound => 'User not found.';

  @override
  String get errorPaymentFailed => 'Payment failed. No charge was confirmed.';

  @override
  String offerResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listings',
      one: '1 listing',
      zero: 'No listings',
    );
    return '$_temp0';
  }

  @override
  String notificationNewMessage(String senderName) {
    return 'New message from $senderName';
  }
}
