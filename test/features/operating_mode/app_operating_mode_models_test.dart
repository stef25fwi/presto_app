import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';

void main() {
  group('AppOperatingMode', () {
    test('normalise les alias commerciaux et les valeurs inconnues', () {
      for (final value in <Object?>['commercial', ' PAID ', 'Payant']) {
        expect(appOperatingModeFromValue(value), AppOperatingMode.commercial);
      }
      for (final value in <Object?>[null, '', 'free_beta', 'inconnu']) {
        expect(appOperatingModeFromValue(value), AppOperatingMode.freeBeta);
      }
    });

    test('expose les valeurs Firestore, libellés et indicateurs', () {
      expect(AppOperatingMode.freeBeta.firestoreValue, 'free_beta');
      expect(AppOperatingMode.freeBeta.label, 'Bêta gratuite');
      expect(AppOperatingMode.freeBeta.isCommercial, isFalse);
      expect(AppOperatingMode.commercial.firestoreValue, 'commercial');
      expect(AppOperatingMode.commercial.label, 'Version payante');
      expect(AppOperatingMode.commercial.isCommercial, isTrue);
    });
  });

  group('LegalPublisherProfile', () {
    test('applique les valeurs par défaut et nettoie les champs', () {
      final profile = LegalPublisherProfile.fromMap(<String, dynamic>{
        'publisherName': '  Éditeur  ',
        'postalAddress': '  1 rue du Test  ',
        'phone': '  0590000000  ',
        'email': '  contact@test.fr  ',
        'publicationDirector': '  Direction  ',
        'companyName': '  Société Test  ',
        'legalForm': '  SASU  ',
        'siren': '  123456789  ',
        'hostingProvider': '   ',
      });

      expect(profile.publisherName, 'Éditeur');
      expect(profile.hostingProvider, contains('Google Ireland Limited'));
      expect(profile.isFreeBetaReady, isTrue);
      expect(profile.isCommercialReady, isTrue);
      expect(profile.isReadyFor(AppOperatingMode.freeBeta), isTrue);
      expect(profile.isReadyFor(AppOperatingMode.commercial), isTrue);
      expect(profile.toMap(), containsPair('email', 'contact@test.fr'));
      expect(profile.toMap(), containsPair('legalForm', 'SASU'));
    });

    test('distingue les exigences bêta et commerciales', () {
      const profile = LegalPublisherProfile(
        publisherName: 'Éditeur',
        postalAddress: 'Adresse',
        phone: '0590000000',
        email: 'contact@test.fr',
        publicationDirector: 'Direction',
        companyName: '',
        legalForm: '',
        siren: '',
        rcs: '',
        shareCapital: '',
        vatNumber: '',
        hostingProvider: 'Hébergeur',
        hostingAddress: 'Adresse hébergeur',
      );

      expect(profile.isFreeBetaReady, isTrue);
      expect(profile.isCommercialReady, isFalse);
      expect(profile.isReadyFor(AppOperatingMode.freeBeta), isTrue);
      expect(profile.isReadyFor(AppOperatingMode.commercial), isFalse);
      expect(LegalPublisherProfile.fromMap(null).isFreeBetaReady, isFalse);
    });
  });

  group('AppOperatingModeState', () {
    test('retourne les valeurs par défaut stables', () {
      final state = AppOperatingModeState.defaults();

      expect(state.mode, AppOperatingMode.freeBeta);
      expect(state.legalVersion, 'beta-free-v1');
      expect(state.cguVersion, 'cgu-beta-free-v1');
      expect(state.privacyVersion, 'privacy-beta-free-v1');
      expect(state.effectiveDate, DateTime.utc(2026, 7, 23));
      expect(state.requiresReacceptance, isFalse);
      expect(state.updatedAt, isNull);
      expect(state.updatedBy, isNull);
    });

    test('parse les versions commerciales et plusieurs formats de date', () {
      final state = AppOperatingModeState.fromMap(<String, dynamic>{
        'operatingMode': 'paid',
        'publisher': <String, dynamic>{
          'publisherName': 'Éditeur',
          'postalAddress': 'Adresse',
          'phone': '0590000000',
          'email': 'contact@test.fr',
          'publicationDirector': 'Direction',
          'companyName': 'Société',
          'legalForm': 'SASU',
          'siren': '123456789',
        },
        'effectiveDate': '2026-08-01T10:00:00Z',
        'updatedAt': 1785607200000,
        'updatedBy': '  admin  ',
        'requiresReacceptance': true,
      });

      expect(state.mode, AppOperatingMode.commercial);
      expect(state.legalVersion, 'commercial-v1');
      expect(state.cguVersion, 'cgu-commercial-v1');
      expect(state.privacyVersion, 'privacy-commercial-v1');
      expect(state.effectiveDate, DateTime.parse('2026-08-01T10:00:00Z'));
      expect(state.updatedAt, isNotNull);
      expect(state.updatedBy, 'admin');
      expect(state.requiresReacceptance, isTrue);
      expect(state.isPublicReady, isTrue);
    });

    test('conserve les versions explicites et tolère les données invalides', () {
      final fallback = AppOperatingModeState.defaults();
      final state = AppOperatingModeState.fromMap(<String, dynamic>{
        'operatingMode': 'free_beta',
        'legalVersion': ' legal-v2 ',
        'cguVersion': ' cgu-v2 ',
        'privacyVersion': ' privacy-v2 ',
        'effectiveDate': 'date-invalide',
        'updatedAt': DateTime.utc(2026, 8, 2),
        'publisher': 'invalide',
      });

      expect(state.legalVersion, 'legal-v2');
      expect(state.cguVersion, 'cgu-v2');
      expect(state.privacyVersion, 'privacy-v2');
      expect(state.effectiveDate, fallback.effectiveDate);
      expect(state.updatedAt, DateTime.utc(2026, 8, 2));
      expect(state.requiresReacceptance, isFalse);
      expect(state.isPublicReady, isFalse);
    });
  });
}
