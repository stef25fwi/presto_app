import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_audio_runtime_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sérialise et restaure une entrée avec valeurs complètes et replis', () {
    final timestamp = DateTime.utc(2026, 7, 25, 8, 30);
    final entry = AdminAudioRuntimeEntry(
      attemptNumber: 4,
      timestamp: timestamp,
      flowKey: 'publish-audio',
      status: 'confirmed',
      label: 'Whisper',
      detail: 'Transcription terminée',
      configuredMode: 'HYBRID',
      backendModeUsed: 'SERVER',
      transcriptLength: 321,
    );

    final restored = AdminAudioRuntimeEntry.fromMap(entry.toMap());
    expect(restored.attemptNumber, 4);
    expect(restored.timestamp, timestamp);
    expect(restored.flowKey, 'publish-audio');
    expect(restored.status, 'confirmed');
    expect(restored.backendModeUsed, 'SERVER');
    expect(restored.transcriptLength, 321);

    final fallback = AdminAudioRuntimeEntry.fromMap(<String, dynamic>{
      'timestamp': 'invalide',
    });
    expect(fallback.attemptNumber, 0);
    expect(fallback.status, 'pending');
    expect(fallback.configuredMode, 'HYBRID');
    expect(fallback.timestamp.millisecondsSinceEpoch, 0);
  });

  test('charge le stockage local puis gère mode, historique, confirmation et effacement',
      () async {
    final seededHistory = List<Map<String, dynamic>>.generate(
      7,
      (index) => AdminAudioRuntimeEntry(
        attemptNumber: index + 1,
        timestamp: DateTime.utc(2026, 7, 20, 8, index),
        flowKey: 'flow-$index',
        status: 'pending',
        label: 'Essai $index',
        detail: 'Détail $index',
        configuredMode: 'LOCAL',
      ).toMap(),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'admin_audio_runtime_store_v1': jsonEncode(<String, dynamic>{
        'attemptCounter': 7,
        'configuredMode': 'local',
        'currentLabel': 'Dernier pipeline',
        'currentDetail': 'Chargé depuis le stockage',
        'backendModeUsed': 'local',
        'dataSource': 'local',
        'lastUpdatedAt': DateTime.utc(2026, 7, 24).toIso8601String(),
        'history': seededHistory,
      }),
    });

    final store = AdminAudioRuntimeStore.instance;
    await store.ensureInitialized();

    expect(store.configuredMode, 'LOCAL');
    expect(store.currentLabel, 'Dernier pipeline');
    expect(store.currentDetail, 'Chargé depuis le stockage');
    expect(store.backendModeUsed, 'local');
    expect(store.dataSource, 'local');
    expect(store.history, hasLength(5));
    expect(store.latestEntry?.attemptNumber, 1);

    var notifications = 0;
    store.addListener(() => notifications += 1);

    store.updateConfiguredMode('  hybrid  ');
    expect(store.configuredMode, 'HYBRID');
    store.updateConfiguredMode('HYBRID');
    store.updateConfiguredMode('   ');
    expect(store.configuredMode, 'HYBRID');

    for (var index = 0; index < 7; index += 1) {
      store.recordRuntime(
        flowKey: 'new-$index',
        label: 'Nouvel essai $index',
        detail: 'Traitement $index',
        status: index.isEven ? 'pending' : 'error',
        backendModeUsed: index == 0 ? '  server  ' : null,
        transcriptLength: 100 + index,
      );
    }

    expect(store.history, hasLength(5));
    expect(store.latestEntry?.flowKey, 'new-6');
    expect(store.dataSource, 'local');

    final previousTranscriptLength = store.latestEntry?.transcriptLength;
    store.confirmLatestBackendResult(
      backendModeUsed: ' cloud ',
      detail: 'Résultat confirmé',
    );
    expect(store.backendModeUsed, 'CLOUD');
    expect(store.currentDetail, 'Résultat confirmé');
    expect(store.latestEntry?.status, 'confirmed');
    expect(store.latestEntry?.transcriptLength, previousTranscriptLength);

    store.confirmLatestBackendResult(
      backendModeUsed: '   ',
      detail: 'ignoré',
    );
    expect(store.currentDetail, 'Résultat confirmé');

    store.clearHistory();
    expect(store.history, isEmpty);
    expect(store.latestEntry, isNull);
    expect(store.currentLabel, 'Mode serveur');
    expect(store.currentDetail, 'Historique effacé');
    expect(store.backendModeUsed, isNull);
    expect(notifications, greaterThan(0));

    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString('admin_audio_runtime_store_v1');
    expect(persisted, isNotNull);
    expect(jsonDecode(persisted!)['history'], isEmpty);
  });
}
