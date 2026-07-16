import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_audio_runtime_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un JSON local invalide est absorbé et réinitialise l historique',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'admin_audio_runtime_store_v1': '{json-invalide',
    });

    final store = AdminAudioRuntimeStore.instance;
    var notifications = 0;
    store.addListener(() => notifications += 1);

    await expectLater(store.ensureInitialized(), completes);

    expect(store.configuredMode, 'HYBRID');
    expect(store.currentLabel, 'Mode serveur');
    expect(store.currentDetail, 'Aucun pipeline recent');
    expect(store.backendModeUsed, isNull);
    expect(store.lastUpdatedAt, isNull);
    expect(store.dataSource, 'local');
    expect(store.latestEntry, isNull);
    expect(store.history, isEmpty);
    expect(notifications, 1);
  });
}
