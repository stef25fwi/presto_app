import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/pages/legal/account_deletion_info_page.dart';
import 'package:presto_app/pages/legal_info_page.dart';
import 'package:presto_app/services/public_landing_config_service.dart';

/// Adaptateur inerte : les assertions portent sur les valeurs par défaut du
/// service, pas sur Remote Config, et Firebase n'est pas initialisé en test.
class _NoopRemoteConfigAdapter implements PublicLandingRemoteConfigAdapter {
  @override
  Future<bool> fetchAndActivate() async => true;

  @override
  bool getBool(String key) => PublicLandingConfigService.defaultEnabled;

  @override
  String getString(String key) => '';

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {}
}

AppOperatingModeService _service({String email = 'contact@ilipresto.fr'}) {
  return AppOperatingModeService(
    firestore: FakeFirebaseFirestore(),
    publicStateLoader: () async => <String, dynamic>{
      'operatingMode': 'free_beta',
      'publisher': <String, dynamic>{'email': email},
    },
  );
}

void main() {
  group('routes légales publiques', () {
    test('chaque route juridique cible le bon onglet', () {
      expect(
        LegalInfoPage.tabForRoute(LegalInfoPage.legalNoticesRouteName),
        0,
      );
      expect(LegalInfoPage.tabForRoute(LegalInfoPage.privacyRouteName), 1);
      expect(LegalInfoPage.tabForRoute(LegalInfoPage.termsRouteName), 2);
    });

    test('une route non légale ne cible aucun onglet', () {
      expect(LegalInfoPage.tabForRoute('/publish'), isNull);
      expect(LegalInfoPage.tabForRoute('/'), isNull);
    });

    test('les chemins juridiques correspondent aux URL attendues', () {
      expect(LegalInfoPage.privacyRouteName, '/confidentialite');
      expect(LegalInfoPage.termsRouteName, '/cgu');
      expect(LegalInfoPage.legalNoticesRouteName, '/mentions-legales');
      expect(AccountDeletionInfoPage.routeName, '/suppression-compte');
    });
  });

  group('page publique de suppression de compte', () {
    testWidgets('décrit les deux procédures et les données concernées',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDeletionInfoPage(operatingModeService: _service()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supprimer votre compte iliprestō'), findsOneWidget);
      expect(find.text('Depuis l’application'), findsOneWidget);
      expect(find.text('Sans passer par l’application'), findsOneWidget);
      expect(find.text('Données supprimées'), findsOneWidget);
      expect(
        find.text('Données conservées après suppression'),
        findsOneWidget,
      );
    });

    testWidgets('propose le contact de l’éditeur quand il est renseigné',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDeletionInfoPage(
            operatingModeService: _service(email: 'legal@ilipresto.fr'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Écrire à legal@ilipresto.fr'), findsOneWidget);
    });

    testWidgets('retombe sur le contact par défaut si aucun n’est enregistré',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDeletionInfoPage(
            operatingModeService: _service(email: ''),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supprimer votre compte iliprestō'), findsOneWidget);
      expect(find.textContaining('Écrire à'), findsOneWidget);
    });
  });

  group('pré-lancement', () {
    test('seuls les mentions légales et les CGU contournent la préouverture', () {
      final config = PublicLandingConfigService(
        adapter: _NoopRemoteConfigAdapter(),
      );

      for (final path in <String>[
        LegalInfoPage.legalNoticesRouteName,
        LegalInfoPage.termsRouteName,
      ]) {
        expect(
          PublicLandingConfigService.bypassPaths.contains(path),
          isTrue,
          reason: '$path doit rester consultable pendant la préouverture',
        );
        expect(
          config.shouldShowFor(
            Uri.parse('https://ilipresto.fr$path'),
            isWeb: true,
          ),
          isFalse,
          reason: '$path ne doit pas afficher la page de préouverture',
        );
      }

      for (final path in <String>[
        LegalInfoPage.privacyRouteName,
        AccountDeletionInfoPage.routeName,
        '/login',
        '/register',
        '/admin',
        '/account',
        '/publish',
      ]) {
        expect(PublicLandingConfigService.bypassPaths.contains(path), isFalse);
        expect(
          config.shouldShowFor(
            Uri.parse('https://ilipresto.fr$path'),
            isWeb: true,
          ),
          isTrue,
          reason: '$path doit rester derrière la page de préouverture',
        );
      }
    });

    testWidgets('masque l’onglet confidentialité sur les pages autorisées',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LegalInfoPage(
            operatingModeService: _service(),
            restrictToPrelaunchLegalTabs: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mentions légales'), findsOneWidget);
      expect(find.text('CGU'), findsOneWidget);
      expect(find.text('Confidentialité'), findsNothing);
    });

    test('la racine publique reste couverte par la préouverture', () {
      final config = PublicLandingConfigService(
        adapter: _NoopRemoteConfigAdapter(),
      );

      expect(
        config.shouldShowFor(Uri.parse('https://ilipresto.fr/'), isWeb: true),
        isTrue,
      );
    });
  });
}
