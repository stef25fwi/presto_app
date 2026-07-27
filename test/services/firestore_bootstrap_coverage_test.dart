import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/firestore_bootstrap.dart';

void main() {
  setUp(resetFirestoreBootstrapForTest);

  test('initialise une seule fois hors web', () async {
    var calls = 0;

    await bootstrapFirestore(
      isWebOverride: false,
      applySettings: () async => calls += 1,
    );
    await bootstrapFirestore(
      isWebOverride: false,
      applySettings: () async => calls += 1,
    );

    expect(calls, 0);
  });

  test('applique les réglages web et devient idempotent', () async {
    var calls = 0;
    final logs = <String>[];

    await bootstrapFirestore(
      isWebOverride: true,
      applySettings: () async => calls += 1,
      logger: logs.add,
    );
    await bootstrapFirestore(
      isWebOverride: true,
      applySettings: () async => calls += 1,
      logger: logs.add,
    );

    expect(calls, 1);
    expect(
      logs,
      contains('[Firestore] web settings applied persistence=false'),
    );
  });

  test('absorbe une erreur puis permet une nouvelle tentative', () async {
    var calls = 0;
    final logs = <String>[];

    await bootstrapFirestore(
      isWebOverride: true,
      applySettings: () async {
        calls += 1;
        throw StateError('settings indisponibles');
      },
      logger: logs.add,
    );

    await bootstrapFirestore(
      isWebOverride: true,
      applySettings: () async => calls += 1,
      logger: logs.add,
    );

    expect(calls, 2);
    expect(
      logs.any((message) => message.contains('settings indisponibles')),
      isTrue,
    );
    expect(
      logs,
      contains('[Firestore] web settings applied persistence=false'),
    );
  });
}
