import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/micro_ia/micro_ia_service.dart';

void main() {
  group('MicroIaService client guards', () {
    test('MicroIaClientAuthException expose son message utilisateur', () {
      const error = MicroIaClientAuthException(
        code: 'auth-missing',
        message: 'Connecte-toi pour utiliser la dictée IA.',
      );

      expect(error.code, 'auth-missing');
      expect(error.message, 'Connecte-toi pour utiliser la dictée IA.');
      expect(error.toString(), error.message);
    });

    test('processAudio refuse un appel sans source audio', () async {
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

    test('processAudio considère une chaîne audio vide comme absente', () async {
      await expectLater(
        MicroIaService.processAudio(audioBase64: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
