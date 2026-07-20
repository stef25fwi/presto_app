import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_audio_runtime_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un stockage JSON valide mais non objet conserve les replis sûrs', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'admin_audio_runtime_store_v1': jsonEncode(<Object?>[
        'entrée inattendue',
        42,
      ]),
    });

    final store = AdminAudioRuntimeStore.instance;
    await store.ensureInitialized();

    expect(store.history, isEmpty);
    expect(store.latestEntry, isNull);
    expect(store.configuredMode, 'HYBRID');
    expect(store.currentLabel, 'Mode serveur');
    expect(store.currentDetail, 'Aucun pipeline recent');
    expect(store.backendModeUsed, isNull);
    expect(store.lastUpdatedAt, isNull);
    expect(store.cloudSyncEnabled, isFalse);
  });
}
