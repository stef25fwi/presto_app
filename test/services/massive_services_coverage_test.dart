import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/ai/trade_classifier_service.dart';
import 'package:presto_app/services/journey_local_storage_service.dart';
import 'package:presto_app/services/pro_siret_service.dart';
import 'package:presto_app/services/product_analytics_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:massive-services',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') {
        rethrow;
      }
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ProductAnalyticsEvent', () {
    test('construit les événements typés avec leur étape', () {
      final events = <ProductAnalyticsEvent>[
        ProductAnalyticsEvent.acquisitionLandingViewed(
          source: 'organic',
          territory: 'GP',
        ),
        ProductAnalyticsEvent.registrationCompleted(
          method: 'email',
          territory: 'GP',
        ),
        ProductAnalyticsEvent.activationFirstValue(
          valueType: 'listing',
          secondsSinceRegistration: 42,
        ),
        ProductAnalyticsEvent.engagementListingContacted(
          categoryId: 'garden',
          territory: 'GP',
          channel: 'chat',
        ),
        ProductAnalyticsEvent.engagementFavoriteChanged(
          listingId: 'listing-1',
          added: true,
        ),
        ProductAnalyticsEvent.conversionPlanSelected(
          planId: 'ilipro',
          billingPeriod: 'monthly',
        ),
        ProductAnalyticsEvent.conversionCheckoutCompleted(
          planId: 'ilipro',
          amount: 9.99,
          currency: 'EUR',
        ),
        ProductAnalyticsEvent.retentionReturned(
          daysSinceRegistration: 7,
          trigger: 'push',
        ),
        ProductAnalyticsEvent.revenueSubscriptionRenewed(
          planId: 'ilipro',
          renewalNumber: 2,
        ),
      ];

      expect(events.map((event) => event.stage).toSet(), {
        ProductFunnelStage.acquisition,
        ProductFunnelStage.registration,
        ProductFunnelStage.activation,
        ProductFunnelStage.engagement,
        ProductFunnelStage.conversion,
        ProductFunnelStage.retention,
        ProductFunnelStage.revenue,
      });
      for (final event in events) {
        expect(event.parameters['funnel_stage'], event.stage.name);
      }
    });

    test('normalise les clés et rend les paramètres immuables', () {
      final event = ProductAnalyticsEvent(
        name: 'custom_event',
        stage: ProductFunnelStage.engagement,
        parameters: const <String, Object?>{
          'CHANNEL': 'chat',
          'count': 2,
          'enabled': true,
          'optional': null,
        },
      );

      expect(event.parameters['channel'], 'chat');
      expect(
        () => event.parameters['extra'] = 'forbidden',
        throwsUnsupportedError,
      );
    });

    test('rejette noms, clés, données personnelles et types invalides', () {
      expect(
        () => ProductAnalyticsEvent(
          name: 'Invalid Name',
          stage: ProductFunnelStage.activation,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProductAnalyticsEvent(
          name: 'valid_name',
          stage: ProductFunnelStage.activation,
          parameters: const <String, Object?>{'bad-key': 1},
        ),
        throwsArgumentError,
      );
      expect(
        () => ProductAnalyticsEvent(
          name: 'valid_name',
          stage: ProductFunnelStage.activation,
          parameters: const <String, Object?>{'email': 'secret@test.fr'},
        ),
        throwsArgumentError,
      );
      expect(
        () => ProductAnalyticsEvent(
          name: 'valid_name',
          stage: ProductFunnelStage.activation,
          parameters: <String, Object?>{'payload': <String>['invalid']},
        ),
        throwsArgumentError,
      );
    });
  });

  group('ProSiretService', () {
    late ProSiretService service;

    setUp(() {
      service = ProSiretService();
    });

    test('nettoie, valide le format et contrôle Luhn', () {
      expect(service.cleanSiret('732 829 320 00074'), '73282932000074');
      expect(service.isValidSiretFormat('732 829 320 00074'), isTrue);
      expect(service.isValidSiretFormat('123'), isFalse);
      expect(service.isValidSiretLuhn('73282932000074'), isTrue);
      expect(service.isValidSiretLuhn('12345678901234'), isFalse);
      expect(service.isValidSiretLuhn('invalid'), isFalse);
    });

    test('parse une réponse complète et ses valeurs par défaut', () {
      final complete = ProSiretVerificationResult.fromMap(<String, dynamic>{
        'ok': true,
        'siret': '73282932000074',
        'siren': '732829320',
        'companyName': 'Entreprise Test',
        'address': '1 rue Test',
        'postalCode': '97122',
        'city': 'Baie-Mahault',
        'nafCode': '6201Z',
        'proStatus': 'verified',
      });
      final empty = ProSiretVerificationResult.fromMap(<String, dynamic>{});

      expect(complete.ok, isTrue);
      expect(complete.companyName, 'Entreprise Test');
      expect(complete.city, 'Baie-Mahault');
      expect(empty.ok, isFalse);
      expect(empty.siret, isEmpty);
      expect(empty.proStatus, isEmpty);
    });

    test('rejette localement les SIRET invalides avant le réseau', () async {
      await expectLater(service.preVerifySiret('123'), throwsA(isA<Exception>()));
      await expectLater(
        service.preVerifySiret('12345678901234'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        service.verifySiret('123'),
        throwsA(isA<ProSiretException>()),
      );
      await expectLater(
        service.verifySiret('12345678901234'),
        throwsA(isA<ProSiretException>()),
      );
      expect(const ProSiretException('erreur').toString(), 'erreur');
    });
  });

  group('JourneyLocalStorageService', () {
    const service = JourneyLocalStorageService();

    test('retourne null sans cache et pour des contenus invalides', () async {
      expect(await service.loadSnapshot(), isNull);
      expect(await service.loadHistorySnapshot(), isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{
        kLocalSavedJourneyPrefsKey: '{invalid-json',
        kLocalHistoryJourneyPrefsKey: jsonEncode(<String>['not-a-map']),
      });

      expect(await service.loadSnapshot(), isNull);
      expect(await service.loadHistorySnapshot(), isNull);
    });

    test('sauvegarde, recharge et écrase l historique local', () async {
      await service.saveHistorySnapshot(<String, dynamic>{
        'projectLabel': 'Premier projet',
        'region': 'GP',
      });
      expect(
        await service.loadHistorySnapshot(),
        containsPair('projectLabel', 'Premier projet'),
      );

      await service.saveHistorySnapshot(<String, dynamic>{
        'projectLabel': 'Deuxième projet',
        'region': 'MQ',
      });
      final history = await service.loadHistorySnapshot();
      expect(history?['projectLabel'], 'Deuxième projet');
      expect(history?['region'], 'MQ');
    });

    test('efface uniquement le snapshot de reprise', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kLocalSavedJourneyPrefsKey: jsonEncode(<String, dynamic>{'id': 'saved'}),
        kLocalHistoryJourneyPrefsKey:
            jsonEncode(<String, dynamic>{'id': 'history'}),
      });

      expect(await service.loadSnapshot(), isNotNull);
      await service.clearSnapshot();
      expect(await service.loadSnapshot(), isNull);
      expect(await service.loadHistorySnapshot(), containsPair('id', 'history'));
    });
  });

  test('TradeClassificationResult expose correctement la confiance', () {
    const uncertain = TradeClassificationResult(
      metier: 'plombier',
      confidence: 0.4,
      match: null,
    );

    expect(uncertain.metier, 'plombier');
    expect(uncertain.confidence, 0.4);
    expect(uncertain.isConfident, isFalse);
  });
}
