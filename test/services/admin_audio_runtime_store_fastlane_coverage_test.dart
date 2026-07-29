import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_audio_runtime_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = AdminAudioRuntimeStore.instance;
    await store.ensureInitialized();
    store.clearHistory();
    store.updateConfiguredMode('HYBRID');
  });

  test('entry round-trips and applies safe defaults', () {
    final entry = AdminAudioRuntimeEntry(
      attemptNumber: 3,
      timestamp: DateTime.utc(2026, 7, 29, 3),
      flowKey: 'publish',
      status: 'confirmed',
      label: 'Transcription',
      detail: 'ok',
      configuredMode: 'HYBRID',
      backendModeUsed: 'VEO',
      transcriptLength: 42,
    );

    final restored = AdminAudioRuntimeEntry.fromMap(entry.toMap());
    expect(restored.attemptNumber, 3);
    expect(restored.timestamp, entry.timestamp);
    expect(restored.backendModeUsed, 'VEO');
    expect(restored.transcriptLength, 42);

    final defaults = AdminAudioRuntimeEntry.fromMap(<String, dynamic>{});
    expect(defaults.attemptNumber, 0);
    expect(defaults.status, 'pending');
    expect(defaults.configuredMode, 'HYBRID');
    expect(defaults.timestamp.millisecondsSinceEpoch, 0);
  });

  test('normalizes mode, limits history and confirms latest result', () {
    final store = AdminAudioRuntimeStore.instance;
    store.updateConfiguredMode('  direct  ');
    expect(store.configuredMode, 'DIRECT');

    for (var i = 0; i < 7; i++) {
      store.recordRuntime(
        flowKey: 'flow-$i',
        label: 'Essai $i',
        detail: 'detail-$i',
        backendModeUsed: i.isEven ? ' hybrid ' : null,
        transcriptLength: i,
      );
    }

    expect(store.history, hasLength(5));
    expect(store.latestEntry?.attemptNumber, 7);
    expect(store.latestEntry?.backendModeUsed, 'HYBRID');

    store.confirmLatestBackendResult(
      backendModeUsed: ' veo ',
      detail: 'confirmé',
      transcriptLength: 99,
    );
    expect(store.backendModeUsed, 'VEO');
    expect(store.currentDetail, 'confirmé');
    expect(store.latestEntry?.status, 'confirmed');
    expect(store.latestEntry?.transcriptLength, 99);
  });

  test('empty confirmation is ignored and clearHistory resets state', () {
    final store = AdminAudioRuntimeStore.instance;
    store.recordRuntime(
      flowKey: 'audio',
      label: 'Audio',
      detail: 'pending',
    );
    final previous = store.backendModeUsed;
    store.confirmLatestBackendResult(
      backendModeUsed: '   ',
      detail: 'ignored',
    );
    expect(store.backendModeUsed, previous);

    store.clearHistory();
    expect(store.history, isEmpty);
    expect(store.latestEntry, isNull);
    expect(store.currentLabel, 'Mode serveur');
    expect(store.currentDetail, 'Historique effacé');
    expect(store.dataSource, 'local');
  });
}
