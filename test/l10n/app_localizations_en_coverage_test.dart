import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/l10n/app_localizations_en.dart';

void main() {
  group('AppLocalizationsEn', () {
    test('exposes every English label', () {
      final l10n = AppLocalizationsEn();

      expect(l10n.localeName, 'en');
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
          'Save',
          'Cancel',
          'Delete',
          'Try again',
          'Close',
          'Continue',
          'Back',
          'Loading…',
          'App language',
          'Automatic — device language',
          'Français',
          'English',
          'Español',
          'The app language has been updated.',
          'Something went wrong. Please try again.',
          'Connection unavailable. Check your internet access.',
          'User not found.',
          'Payment failed. No charge was confirmed.',
        ],
      );
    });

    test('formats result counts and message notifications', () {
      final l10n = AppLocalizationsEn('en_US');

      expect(l10n.localeName, 'en_US');
      expect(l10n.offerResultsCount(0), 'No listings');
      expect(l10n.offerResultsCount(1), '1 listing');
      expect(l10n.offerResultsCount(7), '7 listings');
      expect(l10n.notificationNewMessage('Alex'), 'New message from Alex');
    });
  });
}
