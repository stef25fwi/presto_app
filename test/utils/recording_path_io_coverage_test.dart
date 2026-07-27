import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/recording_path_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('presto_recording_');
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

  test('crée les chemins audio par défaut et personnalisés', () async {
    final defaultPath = await createTempAudioPath();
    final customPath = await createTempAudioPath(
      prefix: 'voice-note',
      extension: '  m4a  ',
    );

    expect(defaultPath, startsWith('${tempDirectory.path}/presto_'));
    expect(defaultPath, endsWith('.wav'));
    expect(customPath, startsWith('${tempDirectory.path}/voice-note_'));
    expect(customPath, endsWith('.m4a'));
  });

  test('utilise wav pour une extension vide et via l alias dédié', () async {
    final fallbackPath = await createTempAudioPath(
      prefix: 'fallback',
      extension: '   ',
    );
    final wavPath = await createTempWavPath(prefix: 'recording');

    expect(fallbackPath, startsWith('${tempDirectory.path}/fallback_'));
    expect(fallbackPath, endsWith('.wav'));
    expect(wavPath, startsWith('${tempDirectory.path}/recording_'));
    expect(wavPath, endsWith('.wav'));
  });
}
