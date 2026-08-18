import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/operating_mode/legal_documents.dart';

const profile = LegalPublisherProfile(
  publisherName: 'Exploitant Test',
  postalAddress: '1 rue de Test, 97122 Baie-Mahault',
  phone: '0590000000',
  email: 'contact@ilipresto.fr',
  publicationDirector: 'Exploitant Test',
  companyName: 'ILIPRESTO',
  legalForm: 'SASU',
  siren: '123456789',
  rcs: 'Pointe-à-Pitre B 123 456 789',
  shareCapital: '1 000 €',
  vatNumber: 'FR00123456789',
  hostingProvider: 'Google Ireland Limited (Firebase Hosting)',
  hostingAddress: 'Gordon House, Dublin 4, Irlande',
);

AppOperatingModeState stateFor(AppOperatingMode mode) => AppOperatingModeState(
      mode: mode,
      publisher: profile,
      legalVersion: mode.isCommercial ? 'commercial-v1' : 'beta-free-v1',
      cguVersion:
          mode.isCommercial ? 'cgu-commercial-v1' : 'cgu-beta-free-v1',
      privacyVersion: mode.isCommercial
          ? 'privacy-commercial-v1'
          : 'privacy-beta-free-v1',
      effectiveDate: DateTime.utc(2026, 7, 23),
      requiresReacceptance: false,
    );

String allText(AppOperatingModeState state) => <String>[
      ...LegalDocumentCatalog.legalNotices(state).map((e) => e.content),
      ...LegalDocumentCatalog.privacy(state).map((e) => e.content),
      ...LegalDocumentCatalog.terms(state).map((e) => e.content),
    ].join('\n');

void main() {
  test('la bêta indique clairement l’absence de monétisation', () {
    final text = allText(stateFor(AppOperatingMode.freeBeta));
    expect(text, contains('Aucun abonnement, paiement ou commission'));
    expect(text, contains('Aucun paiement, abonnement ou moyen de paiement'));
    expect(text, contains('cgu-beta-free-v1'));
    expect(text, contains('privacy-beta-free-v1'));
  });

  test('les documents ne contiennent plus de durée provisoire', () {
    final text = allText(stateFor(AppOperatingMode.freeBeta)).toLowerCase();
    expect(text, isNot(contains('[ex.')));
    expect(text, isNot(contains('à ajuster')));
    expect(text, isNot(contains('dateTime.now'.toLowerCase())));
  });

  test('le document commercial présente les informations de société', () {
    final text = allText(stateFor(AppOperatingMode.commercial));
    expect(text, contains('ILIPRESTO SASU'));
    expect(text, contains('SIREN : 123456789'));
    expect(text, contains('Stripe'));
    expect(text, contains('commercial-v1'));
  });

  test('la politique couvre les données et SDK déclarés aux Stores', () {
    final text = LegalDocumentCatalog.privacy(
      stateFor(AppOperatingMode.freeBeta),
    ).map((section) => section.content).join('\n');

    for (final marker in <String>[
      'SIRET',
      'Firebase App Check',
      'Play Integrity',
      'reCAPTCHA Enterprise',
      'Firebase AI',
      'Google Mobile Ads/AdMob',
      'Google Sign-In',
      'Facebook Login',
      'Sign in with Apple',
      'App Tracking Transparency',
      'https://ilipresto.fr/confidentialite',
      'https://ilipresto.fr/suppression-compte',
    ]) {
      expect(text, contains(marker), reason: 'marqueur Store manquant: $marker');
    }
  });

  test('la vérification téléphone/SIRET ne vaut pas approbation', () {
    final text = LegalDocumentCatalog.privacy(
      stateFor(AppOperatingMode.freeBeta),
    ).map((section) => section.content).join('\n');

    expect(text, contains('ne constitue ni une approbation'));
    expect(text, contains('ni une certification'));
    expect(text, contains('ni une garantie d’Ilipresto'));
  });
}
