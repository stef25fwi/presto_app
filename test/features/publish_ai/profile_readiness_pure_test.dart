import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/publish_ai/profile_readiness.dart';

void main() {
  group('ProfileReadinessResult.describe', () {
    test('utilise une surcharge non vide', () {
      final result = ProfileReadinessResult.blocked(
        gate: ProfileReadinessGate.readFailed,
        messageOverride: '  Message personnalisé  ',
      );

      expect(result.describe(), 'Message personnalisé');
    });

    test('décrit tous les blocages standards', () {
      expect(
        ProfileReadinessResult.blocked(
          gate: ProfileReadinessGate.signedOut,
        ).describe(),
        "Connecte-toi pour utiliser la dictée IA.",
      );
      expect(
        ProfileReadinessResult.blocked(
          gate: ProfileReadinessGate.profileMissing,
        ).describe(),
        "Ton profil n'est pas encore initialisé. Complète-le pour utiliser la dictée IA.",
      );
      expect(
        ProfileReadinessResult.blocked(
          gate: ProfileReadinessGate.readFailed,
        ).describe(),
        "Impossible de vérifier ton profil. Réessaie dans un instant.",
      );
    });

    test('traduit les champs manquants et gère une liste vide', () {
      final fields = ProfileReadinessResult.blocked(
        gate: ProfileReadinessGate.fieldsMissing,
        missingFields: const <String>[
          'displayName',
          'city',
          'postalCode',
          'customField',
        ],
      );
      final empty = ProfileReadinessResult.blocked(
        gate: ProfileReadinessGate.fieldsMissing,
      );

      expect(
        fields.describe(),
        "Complète ton profil (pseudo, ville, code postal, customField) pour utiliser la dictée IA.",
      );
      expect(
        empty.describe(),
        "Complète ton profil pour utiliser la dictée IA.",
      );
    });

    test('un gate absent décrit un profil prêt', () {
      final result = ProfileReadinessResult.blocked(
        gate: ProfileReadinessGate.readFailed,
        messageOverride: '   ',
      );
      expect(result.describe(), isNotEmpty);

      final location = ProfileLocationResolution(
        city: 'Baie-Mahault',
        citySource: 'city',
        postalCode: '97122',
        postalCodeSource: 'postalCode',
      );
      expect(location.blockReason, 'none');
    });
  });

  group('ProfileLocationResolution.blockReason', () {
    test('distingue les trois motifs de blocage', () {
      expect(
        const ProfileLocationResolution(
          city: '',
          citySource: null,
          postalCode: '',
          postalCodeSource: null,
        ).blockReason,
        'missing city and postalCode',
      );
      expect(
        const ProfileLocationResolution(
          city: '',
          citySource: null,
          postalCode: '97122',
          postalCodeSource: 'postalCode',
        ).blockReason,
        'missing city',
      );
      expect(
        const ProfileLocationResolution(
          city: 'Baie-Mahault',
          citySource: 'city',
          postalCode: '',
          postalCodeSource: null,
        ).blockReason,
        'missing postalCode',
      );
    });
  });

  group('ProfileReadinessChecker helpers', () {
    test('firstNonEmptyString respecte l ordre et normalise les valeurs', () {
      expect(
        ProfileReadinessChecker.firstNonEmptyString(
          <String, dynamic>{
            'displayName': '   ',
            'pseudo': '  Stef  ',
            'name': 'Ignoré',
          },
          const <String>['displayName', 'pseudo', 'name'],
        ),
        'Stef',
      );
      expect(
        ProfileReadinessChecker.firstNonEmptyString(
          <String, dynamic>{'value': 42},
          const <String>['value'],
        ),
        '42',
      );
      expect(
        ProfileReadinessChecker.firstNonEmptyString(
          const <String, dynamic>{},
          const <String>['missing'],
        ),
        '',
      );
    });

    test('resolveLocation accepte les alias explicites', () {
      final location = ProfileReadinessChecker.resolveLocation(
        <String, dynamic>{
          'commune': '  Goyave  ',
          'code_postal': ' 97128 ',
        },
      );

      expect(location.city, 'Goyave');
      expect(location.citySource, 'commune');
      expect(location.postalCode, '97128');
      expect(location.postalCodeSource, 'code_postal');
    });

    test('resolveLocation déduit le code postal exact depuis la ville', () {
      final location = ProfileReadinessChecker.resolveLocation(
        <String, dynamic>{'city': 'Baie-Mahault'},
      );

      expect(location.city, 'Baie-Mahault');
      expect(location.postalCode, '97122');
      expect(location.postalCodeSource, 'cityPostalMap[Baie-Mahault]');
    });

    test('resolveLocation retrouve une ville avec casse et espaces différents', () {
      final location = ProfileReadinessChecker.resolveLocation(
        <String, dynamic>{'ville': '  baie-mahault  '},
      );

      expect(location.city, 'baie-mahault');
      expect(location.postalCode, '97122');
      expect(location.postalCodeSource, 'cityPostalMap[Baie-Mahault]');
    });

    test('resolveLocation laisse vide une ville inconnue ou absente', () {
      final unknown = ProfileReadinessChecker.resolveLocation(
        <String, dynamic>{'locality': 'Ville inconnue'},
      );
      final empty = ProfileReadinessChecker.resolveLocation(
        const <String, dynamic>{},
      );

      expect(unknown.city, 'Ville inconnue');
      expect(unknown.postalCode, '');
      expect(unknown.postalCodeSource, isNull);
      expect(empty.city, '');
      expect(empty.postalCode, '');
    });
  });
}
