import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/firebase_init.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(setupFirebaseCoreMocks);

  test('initialise Firebase puis réutilise l application existante', () async {
    expect(firebaseInitPlatformLabel(), isNotEmpty);

    final initialized = await ensureFirebaseInitialized(
      source: 'coverage-first',
    );
    final reused = await ensureFirebaseInitialized(
      source: 'coverage-second',
    );

    expect(Firebase.apps, isNotEmpty);
    expect(reused.name, initialized.name);
    expect(Firebase.app().name, initialized.name);
  });
}
