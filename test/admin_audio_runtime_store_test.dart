import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_audio_runtime_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _entryMap(int attempt) {
  return <String, dynamic>{
    'attemptNumber': attempt,
    'timestamp': DateTime.utc(2026, 7, attempt).toIso8601String(),
    'flowKey': 'flow-$attempt',
    'status': 'pending',
    'label': 'Essai $attempt',
    'detail': 'Détail $attempt',
    'configuredMode': 'server',
    'backendModeUsed': attempt.isEven ? 'cloud' : null,
    'transcriptLength': attempt * 10,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AdminAudioRuntimeEntry sérialise et applique ses valeurs de repli', () {
    final timestamp = DateTime.utc(2026, 7, 16, 10, 30);
    final entry = AdminAudioRuntimeEntry(
      attemptNumber: 4,
      timestamp: timestamp,
      flowKey: 'publication',
      status: 'confirmed',
      label: 'Mode Gemini',
      detail: 'Transcription terminée',
      configuredMode: 'HYBRID',
      backendModeUsed: 'CLOUD',
      transcriptLength: 125,
    );

    final map = entry.toMap();
    expect(map, <String, dynamic>{
      'attemptNumber': 4,
      'timestamp': timestamp.toIso8601String(),
      'flowKey': 'publication',
      'status': 'confirmed',
      'label': 'Mode Gemini',
      'detail': 'Transcription terminée',
      'configuredMode': 'HYBRID',
      'backendModeUsed': 'CLOUD',
      'transcriptLength': 125,
    });

    final restored = AdminAudioRuntimeEntry.fromMap(map);
    expect(restored.attemptNumber, 4);
    expect(restored.timestamp, timestamp);
    expect(restored.flowKey, 'publication');
    expect(restored.status, 'confirmed');
    expect(restored.backendModeUsed, 'CLOUD');
    expect(restored.transcriptLength, 125);

    final fallback = AdminAudioRuntimeEntry.fromMap(<String, dynamic>{
      'timestamp': 'date-invalide',
    });
    expect(fallback.attemptNumber, 0);
    expect(fallback.timestamp, DateTime.fromMillisecondsSinceEpoch(0));
    expect(fallback.flowKey, isEmpty);
    expect(fallback.status, 'pending');
    expect(fallback.label, isEmpty);
    expect(fallback.detail, isEmpty);
    expect(fallback.configuredMode, 'HYBRID');
    expect(fallback.backendModeUsed, isNull);
    expect(fallback.transcriptLength, isNull);
  });

  test('le store charge, normalise, limite, confirme et persiste l historique',
      () async {
    final seededHistory = <Map<String, dynamic>>[
      for (var attempt = 6; attempt >= 1; attempt -= 1) _entryMap(attempt),
    ];
    final seededTimestamp = DateTime.utc(2026, 7, 15, 12);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'admin_audio_runtime_store_v1': jsonEncode(<String, dynamic>{
        'attemptCounter': 12,
        'configuredMode': 'server',
        'currentLabel': 'Pipeline distant',
        'currentDetail': 'Dernier état distant',
        'backendModeUsed': 'cloud',
        'dataSource': 'cloud',
        'lastUpdatedAt': seededTimestamp.toIso8601String(),
        'history': seededHistory,
      }),
    });

    final store = AdminAudioRuntimeStore.instance;
    var notifications = 0;
    void listener() => notifications += 1;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));

    final firstInitialization = store.ensureInitialized();
    final secondInitialization = store.ensureInitialized();
    expect(identical(firstInitialization, secondInitialization), isTrue);
    await firstInitialization;

    expect(store.configuredMode, 'SERVER');
    expect(store.currentLabel, 'Pipeline distant');
    expect(store.currentDetail, 'Dernier état distant');
    expect(store.backendModeUsed, 'cloud');
    expect(store.lastUpdatedAt, seededTimestamp);
    expect(store.dataSource, 'cloud');
    expect(store.cloudSyncEnabled, isFalse);
    expect(store.history, hasLength(5));
    expect(store.latestEntry?.attemptNumber, 6);
    expect(store.history, isA<List<AdminAudioRuntimeEntry>>());
    expect(
      () => store.history.add(
        AdminAudioRuntimeEntry.fromMap(_entryMap(99)),
      ),
      throwsUnsupportedError,
    );

    final afterLoadNotifications = notifications;
    store.updateConfiguredMode(' server ');
    expect(notifications, afterLoadNotifications);

    store.updateConfiguredMode('   ');
    expect(store.configuredMode, 'HYBRID');
    expect(store.dataSource, 'local');
    expect(notifications, afterLoadNotifications + 1);

    store.updateConfiguredMode('hybrid');
    expect(notifications, afterLoadNotifications + 1);

    store.recordRuntime(
      flowKey: 'paiement',
      label: 'Essai local',
      detail: 'Backend en attente',
      backendModeUsed: '   ',
      transcriptLength: 42,
    );
    expect(store.latestEntry?.attemptNumber, 13);
    expect(store.latestEntry?.status, 'pending');
    expect(store.latestEntry?.backendModeUsed, isNull);
    expect(store.latestEntry?.transcriptLength, 42);
    expect(store.backendModeUsed, isNull);
    expect(store.currentLabel, 'Essai local');
    expect(store.currentDetail, 'Backend en attente');
    expect(store.lastUpdatedAt, isNotNull);

    for (var index = 0; index < 5; index += 1) {
      store.recordRuntime(
        flowKey: 'publication-$index',
        label: 'Nouvel essai $index',
        detail: 'Détail $index',
        status: index.isEven ? 'success' : 'pending',
        backendModeUsed: ' cloud ',
        transcriptLength: 100 + index,
      );
    }

    expect(store.history, hasLength(5));
    expect(store.latestEntry?.attemptNumber, 18);
    expect(store.latestEntry?.backendModeUsed, 'CLOUD');
    expect(store.latestEntry?.configuredMode, 'HYBRID');
    expect(store.history.last.attemptNumber, 14);

    final beforeBlankConfirmation = store.latestEntry;
    store.confirmLatestBackendResult(
      backendModeUsed: '   ',
      detail: 'Ignoré',
    );
    expect(store.latestEntry, same(beforeBlankConfirmation));

    final originalTimestamp = store.latestEntry!.timestamp;
    final originalLabel = store.latestEntry!.label;
    store.confirmLatestBackendResult(
      backendModeUsed: ' gemini ',
      detail: 'Résultat confirmé',
      transcriptLength: 999,
    );
    expect(store.backendModeUsed, 'GEMINI');
    expect(store.currentDetail, 'Résultat confirmé');
    expect(store.dataSource, 'local');
    expect(store.latestEntry?.status, 'confirmed');
    expect(store.latestEntry?.detail, 'Résultat confirmé');
    expect(store.latestEntry?.backendModeUsed, 'GEMINI');
    expect(store.latestEntry?.transcriptLength, 999);
    expect(store.latestEntry?.timestamp, originalTimestamp);
    expect(store.latestEntry?.label, originalLabel);

    await pumpEventQueue(times: 4);
    final prefs = await SharedPreferences.getInstance();
    final persistedBeforeClear = jsonDecode(
      prefs.getString('admin_audio_runtime_store_v1')!,
    ) as Map<String, dynamic>;
    expect(persistedBeforeClear['attemptCounter'], 18);
    expect(persistedBeforeClear['configuredMode'], 'HYBRID');
    expect(persistedBeforeClear['backendModeUsed'], 'GEMINI');
    expect(persistedBeforeClear['history'], hasLength(5));

    store.clearHistory();
    expect(store.latestEntry, isNull);
    expect(store.history, isEmpty);
    expect(store.currentLabel, 'Mode serveur');
    expect(store.currentDetail, 'Historique effacé');
    expect(store.backendModeUsed, isNull);
    expect(store.dataSource, 'local');
    expect(store.lastUpdatedAt, isNotNull);

    store.confirmLatestBackendResult(
      backendModeUsed: 'local',
      detail: 'Confirmation sans historique',
      transcriptLength: 12,
    );
    expect(store.backendModeUsed, 'LOCAL');
    expect(store.currentDetail, 'Confirmation sans historique');
    expect(store.history, isEmpty);

    await pumpEventQueue(times: 4);
    final persistedAfterClear = jsonDecode(
      prefs.getString('admin_audio_runtime_store_v1')!,
    ) as Map<String, dynamic>;
    expect(persistedAfterClear['attemptCounter'], 0);
    expect(persistedAfterClear['currentLabel'], 'Mode serveur');
    expect(persistedAfterClear['currentDetail'], 'Confirmation sans historique');
    expect(persistedAfterClear['backendModeUsed'], 'LOCAL');
    expect(persistedAfterClear['history'], isEmpty);
  });
}
