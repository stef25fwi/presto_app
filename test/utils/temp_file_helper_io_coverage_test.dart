import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/temp_file_helper_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('presto_temp_file_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getTemporaryDirectory') {
        return tempDirectory.path;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('écrit, normalise, lit puis supprime un fichier temporaire', () async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final path = await writeTempFile(
      bytes,
      fileName: '  pièce   jointe?.pdf  ',
    );

    expect(path, startsWith('${tempDirectory.path}/'));
    expect(path, endsWith('_pi_ce_jointe_.pdf'));
    expect(await readTempFile(path), bytes);

    deleteTempFile(path);
    expect(File(path).existsSync(), isFalse);
    deleteTempFile(path);
  });

  test('utilise le nom de secours lorsque le nom est vide', () async {
    final path = await writeTempFile(
      Uint8List.fromList(<int>[9]),
      fileName: '   ',
    );

    expect(path, endsWith('_piece_jointe.bin'));
    expect(await readTempFile(path), Uint8List.fromList(<int>[9]));
  });
}
