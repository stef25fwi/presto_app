import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_app.dart';

void main() {
  group('resolvePublicPrelaunchEntryMode', () {
    test('isole uniquement mentions légales et CGU sur le domaine public', () {
      expect(
        resolvePublicPrelaunchEntryMode(
          Uri.parse('https://ilipresto.fr/mentions-legales'),
          enabled: true,
          hasDeveloperAccess: false,
          isWeb: true,
        ),
        PublicPrelaunchEntryMode.legalNotices,
      );
      expect(
        resolvePublicPrelaunchEntryMode(
          Uri.parse('https://ilipresto.fr/cgu'),
          enabled: true,
          hasDeveloperAccess: false,
          isWeb: true,
        ),
        PublicPrelaunchEntryMode.terms,
      );
    });

    test('bloque toutes les autres routes applicatives en préouverture', () {
      for (final path in <String>[
        '/',
        '/login',
        '/register',
        '/admin',
        '/account',
        '/publish',
        '/messages',
        '/messages-2',
        '/confidentialite',
        '/suppression-compte',
        '/offers/123',
        '/profile/user-1',
      ]) {
        expect(
          resolvePublicPrelaunchEntryMode(
            Uri.parse('https://ilipresto.fr$path'),
            enabled: true,
            hasDeveloperAccess: false,
            isWeb: true,
          ),
          PublicPrelaunchEntryMode.landing,
          reason: '$path ne doit jamais initialiser le Navigator principal',
        );
      }
    });

    test('ne traite pas les fragments comme une route légale autorisée', () {
      expect(
        resolvePublicPrelaunchEntryMode(
          Uri.parse('https://ilipresto.fr/#/cgu'),
          enabled: true,
          hasDeveloperAccess: false,
          isWeb: true,
        ),
        PublicPrelaunchEntryMode.landing,
      );
      expect(
        resolvePublicPrelaunchEntryMode(
          Uri.parse('https://ilipresto.fr/#/mentions-legales'),
          enabled: true,
          hasDeveloperAccess: false,
          isWeb: true,
        ),
        PublicPrelaunchEntryMode.landing,
      );
    });

    test('autorise l application uniquement après accès développeur', () {
      expect(
        resolvePublicPrelaunchEntryMode(
          Uri.parse('https://ilipresto.fr/login'),
          enabled: true,
          hasDeveloperAccess: true,
          isWeb: true,
        ),
        PublicPrelaunchEntryMode.application,
      );
    });

    test('autorise l application lorsque la préouverture est désactivée', () {
      expect(
        resolvePublicPrelaunchEntryMode(
          Uri.parse('https://ilipresto.fr/account'),
          enabled: false,
          hasDeveloperAccess: false,
          isWeb: true,
        ),
        PublicPrelaunchEntryMode.application,
      );
    });

    test('ne bloque pas les environnements non publics', () {
      expect(
        resolvePublicPrelaunchEntryMode(
          Uri.parse('https://preview.example.dev/login'),
          enabled: true,
          hasDeveloperAccess: false,
          isWeb: true,
        ),
        PublicPrelaunchEntryMode.application,
      );
    });
  });
}
