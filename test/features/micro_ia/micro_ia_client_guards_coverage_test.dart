import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/micro_ia/micro_ia_service.dart';

void main() {
  test('MicroIaClientAuthException expose son code et son message', () {
    const error = MicroIaClientAuthException(
      code: 'auth-missing',
      message: 'Connecte-toi pour utiliser la dictée IA.',
    );

    expect(error.code, 'auth-missing');
    expect(error.message, contains('Connecte-toi'));
    expect(error.toString(), error.message);
  });

  test('processAudio refuse un appel sans audio ni chemin Storage', () async {
    await expectLater(
      MicroIaService.processAudio(),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('storagePath or audioBase64'),
        ),
      ),
    );
  });

  test('processAudio refuse aussi les chaînes audio vides', () async {
    await expectLater(
      MicroIaService.processAudio(
        storagePath: '',
        audioBase64: '',
        audioContentType: 'audio/webm',
      ),
      throwsArgumentError,
    );
  });
}
