import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cache_monitoring_service.dart';
import 'package:presto_app/services/toolbox_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  late FakeFirebaseFirestore firestore;
  late CacheMonitoringService monitoring;
  late ToolboxCacheService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    monitoring = CacheMonitoringService()..reset();
    service = ToolboxCacheService(
      firestore: firestore,
      monitoring: monitoring,
    );
  });

  test('enregistre un miss lorsque l index est absent', () async {
    final result = await service.fetchExistingJourney(
      typeProjet: '  Créer – une Société  ',
      domaine: 'Bâtiment / Décoration & œuvre',
      region: 'Guadeloupe_Îles',
    );

    expect(result, isNull);
    expect(monitoring.metrics.totalRequests, 1);
    expect(monitoring.metrics.cacheMisses, 1);
    expect(monitoring.metrics.cacheHits, 0);
  });

  test('enregistre un miss lorsque l index ne contient pas de journey id', () async {
    await firestore.collection('toolbox_journey_index').add(<String, dynamic>{
      'criteria_hash': 'creation|artisanat|guadeloupe',
      'journey_id': null,
    });

    final result = await service.fetchExistingJourney(
      typeProjet: 'Création',
      domaine: 'Artisanat',
      region: 'Guadeloupe',
    );

    expect(result, isNull);
    expect(monitoring.metrics.cacheMisses, 1);
  });

  test('enregistre un miss lorsque le parcours indexé a disparu', () async {
    await firestore.collection('toolbox_journey_index').add(<String, dynamic>{
      'criteria_hash': 'reprise|commerce|martinique',
      'journey_id': 'missing-journey',
    });

    final result = await service.fetchExistingJourney(
      typeProjet: 'Reprise',
      domaine: 'Commerce',
      region: 'Martinique',
    );

    expect(result, isNull);
    expect(monitoring.metrics.cacheMisses, 1);
  });

  test('sauvegarde, indexe et relit un parcours normalisé', () async {
    final journeyId = await service.saveNewJourney(
      typeProjet: '  Création d’entreprise  ',
      domaine: 'Santé / Bien-être',
      region: 'Guadeloupe_Îles',
      journeyContent: const <String, dynamic>{
        'steps': <String>['diagnostic', 'immatriculation'],
      },
    );

    expect(journeyId, isNotNull);
    final journey = await firestore
        .collection('toolbox_journeys')
        .doc(journeyId)
        .get();
    expect(journey.exists, isTrue);
    expect(
      journey.data()?['criteria_hash'],
      'creation d entreprise|sante bien etre|guadeloupe iles',
    );
    expect(journey.data()?['content'], <String, dynamic>{
      'steps': <String>['diagnostic', 'immatriculation'],
    });

    final index = await firestore
        .collection('toolbox_journey_index')
        .where(
          'criteria_hash',
          isEqualTo: 'creation d entreprise|sante bien etre|guadeloupe iles',
        )
        .get();
    expect(index.docs, hasLength(1));
    expect(index.docs.single.data()['journey_id'], journeyId);

    final cached = await service.fetchExistingJourney(
      typeProjet: 'CREATION D’ENTREPRISE',
      domaine: 'santé_bien-être',
      region: 'guadeloupe îles',
    );
    expect(cached?['type_projet'], '  Création d’entreprise  ');
    expect(monitoring.metrics.cacheHits, 1);
  });

  test('réutilise l index existant pour une nouvelle génération', () async {
    final firstId = await service.saveNewJourney(
      typeProjet: 'Création',
      domaine: 'Numérique',
      region: 'Guyane',
      journeyContent: const <String, dynamic>{'version': 1},
    );
    final initialIndex = await firestore
        .collection('toolbox_journey_index')
        .where(
          'criteria_hash',
          isEqualTo: 'creation|numerique|guyane',
        )
        .get();
    final indexId = initialIndex.docs.single.id;

    final secondId = await service.saveNewJourney(
      typeProjet: ' création ',
      domaine: 'NUMÉRIQUE',
      region: 'Guyane',
      journeyContent: const <String, dynamic>{'version': 2},
    );

    expect(secondId, isNot(firstId));
    final updatedIndex = await firestore
        .collection('toolbox_journey_index')
        .where(
          'criteria_hash',
          isEqualTo: 'creation|numerique|guyane',
        )
        .get();
    expect(updatedIndex.docs, hasLength(1));
    expect(updatedIndex.docs.single.id, indexId);
    expect(updatedIndex.docs.single.data()['journey_id'], secondId);
  });

  test('supprime le parcours et toutes ses entrées d index', () async {
    final journeyId = await service.saveNewJourney(
      typeProjet: 'Reprise',
      domaine: 'Commerce',
      region: 'Martinique',
      journeyContent: const <String, dynamic>{'ready': true},
    );
    await firestore.collection('toolbox_journey_index').add(<String, dynamic>{
      'criteria_hash': 'legacy',
      'journey_id': journeyId,
    });

    final deleted = await service.deleteJourney(
      journeyId: journeyId!,
      criteriaHash: 'reprise|commerce|martinique',
    );

    expect(deleted, isTrue);
    expect(
      (await firestore.collection('toolbox_journeys').doc(journeyId).get())
          .exists,
      isFalse,
    );
    final remainingIndexes = await firestore
        .collection('toolbox_journey_index')
        .where('journey_id', isEqualTo: journeyId)
        .get();
    expect(remainingIndexes.docs, isEmpty);
  });

  test('retourne le nombre de parcours uniques', () async {
    await firestore.collection('toolbox_journeys').doc('journey-1').set(
      const <String, dynamic>{'content': <String, dynamic>{}},
    );
    await firestore.collection('toolbox_journeys').doc('journey-2').set(
      const <String, dynamic>{'content': <String, dynamic>{}},
    );

    expect(await service.getCacheStats(), 2);
  });

  test('recordCacheMiss délègue au monitoring injecté', () {
    service.recordCacheMiss(const Duration(milliseconds: 250));

    expect(monitoring.metrics.totalRequests, 1);
    expect(monitoring.metrics.cacheMisses, 1);
    expect(monitoring.metrics.avgAccessTime, const Duration(milliseconds: 250));
  });
}
