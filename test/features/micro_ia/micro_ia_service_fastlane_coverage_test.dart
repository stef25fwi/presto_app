import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/micro_ia/micro_ia_service.dart';

void main() {
  test('MicroIaClientAuthException exposes its code and user message', () {
    const error = MicroIaClientAuthException(
      code: 'auth-missing',
      message: 'Connecte-toi pour utiliser la dictée IA.',
    );

    expect(error.code, 'auth-missing');
    expect(error.message, 'Connecte-toi pour utiliser la dictée IA.');
    expect(error.toString(), error.message);
  });

  test('processAudio rejects a request without inline audio or storage path',
      () async {
    await expectLater(
      MicroIaService.processAudio(),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          'processAudio requires either storagePath or audioBase64.',
        ),
      ),
    );
  });

  test('processAudio also rejects empty audio inputs', () async {
    await expectLater(
      MicroIaService.processAudio(
        storagePath: '',
        audioBase64: '',
        audioContentType: 'audio/webm',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
