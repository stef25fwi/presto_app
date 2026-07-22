import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/journey_local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const service = JourneyLocalStorageService();

  test('retourne null pour absence, chaîne vide, JSON invalide ou liste', () async {
    expect(await service.loadSnapshot(), isNull);

    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: '',
    });
    expect(await service.loadSnapshot(), isNull);

    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: '{invalide',
    });
    expect(await service.loadSnapshot(), isNull);

    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: jsonEncode(<Object>[1, 2]),
    });
    expect(await service.loadSnapshot(), isNull);
  });

  test('charge une sauvegarde locale puis l efface', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: jsonEncode(<String, dynamic>{
        'projectLabel': 'Boutique',
        '_cloudJourneyId': 'journey-1',
      }),
    });

    expect(await service.loadSnapshot(), <String, dynamic>{
      'projectLabel': 'Boutique',
      '_cloudJourneyId': 'journey-1',
    });

    await service.clearSnapshot();
    expect(await service.loadSnapshot(), isNull);
  });

  test('sauvegarde et remplace l historique local', () async {
    await service.saveHistorySnapshot(<String, dynamic>{
      'projectLabel': 'Premier',
      'steps': <int>[1, 2],
    });
    expect(await service.loadHistorySnapshot(), <String, dynamic>{
      'projectLabel': 'Premier',
      'steps': <dynamic>[1, 2],
    });

    await service.saveHistorySnapshot(<String, dynamic>{
      'projectLabel': 'Second',
      'completed': true,
    });
    expect(await service.loadHistorySnapshot(), <String, dynamic>{
      'projectLabel': 'Second',
      'completed': true,
    });
  });
}
