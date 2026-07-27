import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';
import 'package:presto_app/services/journey_local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves snapshots, strips metadata and reuses the matching cloud id',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final calls = <Map<String, dynamic>>[];
    final service = JourneyLocalStorageService(
      saveJourneyCaller: (snapshot, {journeyId}) async {
        calls.add(<String, dynamic>{
          'snapshot': Map<String, dynamic>.from(snapshot),
          'journeyId': journeyId,
        });
        return 'cloud-${calls.length}';
      },
    );
    final snapshot = <String, dynamic>{
      'projectLabel': ' Mon activité ',
      'selectedActivity': 'Artisanat',
      'currentStatus': 'Fonctionnaire',
      'region': 'Guadeloupe',
      '_localOnly': true,
    };

    await service.saveSnapshot(snapshot);

    expect(calls, hasLength(1));
    expect(calls.first['journeyId'], isNull);
    expect(
      calls.first['snapshot'],
      <String, dynamic>{
        'projectLabel': ' Mon activité ',
        'selectedActivity': 'Artisanat',
        'currentStatus': 'Fonctionnaire',
        'region': 'Guadeloupe',
      },
    );
    final firstCache = await service.loadSnapshot();
    expect(firstCache?['_cloudJourneyId'], 'cloud-1');
    expect(
      firstCache?['_journeyIdentity'],
      'mon activité|artisanat|fonctionnaire|guadeloupe',
    );
    expect(firstCache?['_localOnly'], isTrue);

    await service.saveSnapshot(snapshot);
    expect(calls[1]['journeyId'], 'cloud-1');

    await service.saveSnapshot(<String, dynamic>{
      ...snapshot,
      'region': 'Martinique',
    });
    expect(calls[2]['journeyId'], isNull);
    expect((await service.loadSnapshot())?['_cloudJourneyId'], 'cloud-3');
  });

  test('builds the journey identity from summary fallbacks', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = JourneyLocalStorageService(
      saveJourneyCaller: (snapshot, {journeyId}) async => 'summary-cloud',
    );

    await service.saveSnapshot(<String, dynamic>{
      'summary': <String, dynamic>{
        'title': ' Projet résumé ',
        'activity': 'Services',
        'currentStatus': 'Sans emploi',
        'region': 'Guyane',
      },
    });

    final cache = await service.loadSnapshot();
    expect(
      cache?['_journeyIdentity'],
      'projet résumé|services|sans emploi|guyane',
    );
  });

  test('loads, clears and rejects malformed local payloads', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: '',
    });
    const service = JourneyLocalStorageService();
    final prefs = await SharedPreferences.getInstance();

    expect(await service.loadSnapshot(), isNull);

    await prefs.setString(kLocalSavedJourneyPrefsKey, '[]');
    expect(await service.loadSnapshot(), isNull);

    await prefs.setString(kLocalSavedJourneyPrefsKey, '{invalid');
    expect(await service.loadSnapshot(), isNull);

    await prefs.setString(
      kLocalSavedJourneyPrefsKey,
      jsonEncode(<String, dynamic>{'value': 1}),
    );
    expect(await service.loadSnapshot(), <String, dynamic>{'value': 1});

    await service.saveHistorySnapshot(<String, dynamic>{'history': true});
    expect(
      await service.loadHistorySnapshot(),
      <String, dynamic>{'history': true},
    );

    await service.clearSnapshot();
    expect(await service.loadSnapshot(), isNull);
    expect(
      await service.loadHistorySnapshot(),
      <String, dynamic>{'history': true},
    );
  });

  test('loads the library and clears only a matching cached journey', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kLocalSavedJourneyPrefsKey: jsonEncode(<String, dynamic>{
        '_cloudJourneyId': 'journey-1',
        'projectLabel': 'Projet',
      }),
    });
    final deletedIds = <String>[];
    const record = SavedJourneyRecord(
      id: 'journey-1',
      title: 'Projet',
      activity: 'Services',
      currentStatus: 'Fonctionnaire',
      region: 'Guadeloupe',
      createdAt: null,
      updatedAt: null,
      snapshot: <String, dynamic>{'projectLabel': 'Projet'},
    );
    final service = JourneyLocalStorageService(
      listJourneysCaller: () async => const <SavedJourneyRecord>[record],
      deleteJourneyCaller: (journeyId) async => deletedIds.add(journeyId),
    );

    expect(await service.loadLibrary(), const <SavedJourneyRecord>[record]);

    await service.deleteLibraryJourney('journey-other');
    expect(deletedIds, <String>['journey-other']);
    expect(await service.loadSnapshot(), isNotNull);

    await service.deleteLibraryJourney('journey-1');
    expect(deletedIds, <String>['journey-other', 'journey-1']);
    expect(await service.loadSnapshot(), isNull);

    await service.deleteLibraryJourney('journey-missing');
    expect(
      deletedIds,
      <String>['journey-other', 'journey-1', 'journey-missing'],
    );
  });
}
