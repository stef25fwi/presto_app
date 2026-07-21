import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/toolbox_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('normalise les critères avant un cache miss sûr', () async {
    final service = ToolboxCacheService();

    final result = await service.fetchExistingJourney(
      typeProjet: '  Créer – une Société  ',
      domaine: 'Bâtiment / Décoration & œuvre',
      region: 'Guadeloupe_Îles',
    );

    expect(result, isNull);
  });

  test('retourne null lorsque la sauvegarde Firestore est indisponible',
      () async {
    final service = ToolboxCacheService();

    final result = await service.saveNewJourney(
      typeProjet: 'Reprise d’entreprise',
      domaine: 'Santé / bien-être',
      region: 'Martinique',
      journeyContent: const <String, dynamic>{
        'steps': <String>['diagnostic', 'financement'],
      },
    );

    expect(result, isNull);
  });

  test('retourne false lorsque la suppression Firestore échoue', () async {
    final service = ToolboxCacheService();

    final result = await service.deleteJourney(
      journeyId: 'journey-test',
      criteriaHash: 'creation|artisanat|guyane',
    );

    expect(result, isFalse);
  });

  test('retourne zéro lorsque les statistiques sont indisponibles', () async {
    final service = ToolboxCacheService();

    expect(await service.getCacheStats(), 0);
  });

  test('enregistre explicitement un cache miss sans erreur', () {
    final service = ToolboxCacheService();

    expect(
      () => service.recordCacheMiss(const Duration(milliseconds: 275)),
      returnsNormally,
    );
  });
}
