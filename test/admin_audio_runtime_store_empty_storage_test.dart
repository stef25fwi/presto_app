import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_audio_runtime_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un stockage vide conserve les valeurs locales par défaut', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final store = AdminAudioRuntimeStore.instance;
    var notifications = 0;
    store.addListener(() => notifications += 1);

    await store.ensureInitialized();

    expect(store.configuredMode, 'HYBRID');
    expect(store.currentLabel, 'Mode serveur');
    expect(store.currentDetail, 'Aucun pipeline recent');
    expect(store.backendModeUsed, isNull);
    expect(store.lastUpdatedAt, isNull);
    expect(store.dataSource, 'local');
    expect(store.cloudSyncEnabled, isFalse);
    expect(store.latestEntry, isNull);
    expect(store.history, isEmpty);
    expect(notifications, 0);
  });
}
