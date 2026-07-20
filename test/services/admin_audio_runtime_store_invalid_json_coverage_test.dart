import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_audio_runtime_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un stockage JSON corrompu est ignoré sans casser le store', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'admin_audio_runtime_store_v1': '{json-corrompu',
    });

    final store = AdminAudioRuntimeStore.instance;
    var notifications = 0;
    void listener() => notifications += 1;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));

    await store.ensureInitialized();

    expect(store.history, isEmpty);
    expect(store.latestEntry, isNull);
    expect(store.configuredMode, 'HYBRID');
    expect(store.currentLabel, 'Mode serveur');
    expect(store.currentDetail, 'Aucun pipeline recent');
    expect(store.dataSource, 'local');
    expect(notifications, 1);
  });
}
