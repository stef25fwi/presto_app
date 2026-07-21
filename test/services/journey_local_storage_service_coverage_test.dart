import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/journey_local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = JourneyLocalStorageService();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('charge null quand le cache est absent ou vide', () async {
    expect(await service.loadSnapshot(), isNull);

    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: '',
    });
    expect(await service.loadSnapshot(), isNull);
  });

  test('charge une map JSON valide depuis le cache', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: jsonEncode(<String, dynamic>{
        'projectLabel': 'Salon de coiffure',
        'region': 'Guadeloupe',
        'steps': <String>['a', 'b'],
      }),
    });

    final snapshot = await service.loadSnapshot();

    expect(snapshot, isNotNull);
    expect(snapshot!['projectLabel'], 'Salon de coiffure');
    expect(snapshot['region'], 'Guadeloupe');
    expect(snapshot['steps'], <String>['a', 'b']);
  });

  test('retourne null pour JSON invalide ou valeur non-map', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: '{invalide',
    });
    expect(await service.loadSnapshot(), isNull);

    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: jsonEncode(<String>['a', 'b']),
    });
    expect(await service.loadSnapshot(), isNull);
  });

  test('sauvegarde et recharge l historique local', () async {
    final snapshot = <String, dynamic>{
      'projectLabel': 'Food truck',
      'currentStatus': 'creation',
      'region': 'Martinique',
    };

    await service.saveHistorySnapshot(snapshot);

    expect(await service.loadHistorySnapshot(), snapshot);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kLocalHistoryJourneyPrefsKey), jsonEncode(snapshot));
  });

  test('efface uniquement le cache de reprise', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: jsonEncode(<String, dynamic>{'id': 'saved'}),
      kLocalHistoryJourneyPrefsKey: jsonEncode(<String, dynamic>{'id': 'history'}),
    });

    await service.clearSnapshot();

    expect(await service.loadSnapshot(), isNull);
    expect(await service.loadHistorySnapshot(), <String, dynamic>{'id': 'history'});
  });
}
