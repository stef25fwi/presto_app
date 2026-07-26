import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/public_offers_read_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Public offers diagnostics edge coverage', () {
    test('reconnaît chaque variante de signal token App Check', () {
      for (final message in <String>[
        'token app invalide',
        'token check invalide',
        'token attest invalide',
      ]) {
        final issue = diagnosePublicOffersReadIssue(
          StateError(message),
          source: 'coverage',
          appCheckState: 'failed',
          hasAuthenticatedUser: false,
        );

        expect(issue.kind, 'app_check');
        expect(issue.appCheckState, 'failed');
        expect(issue.hasAuthenticatedUser, isFalse);
        expect(issue.releaseMessage, contains('App Check'));
      }
    });

    test('construit le message convivial pour une erreur brute', () {
      final message = friendlyPublicOffersReadError(
        StateError('erreur métier inconnue'),
        source: 'coverage-friendly',
        appCheckState: 'ok',
        hasAuthenticatedUser: true,
        debug: false,
      );

      expect(message, 'Impossible de charger les annonces pour le moment.');
    });

    test('journalise sans stack trace fournie', () async {
      expect(
        () => logPublicOffersReadError(
          'coverage-log',
          StateError('network unavailable'),
          appCheckState: 'ok',
          hasAuthenticatedUser: false,
        ),
        returnsNormally,
      );

      await Future<void>.delayed(Duration.zero);
    });
  });
}
