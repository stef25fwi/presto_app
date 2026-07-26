import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/pro_siret_service.dart';

void main() {
  final service = ProSiretService();

  test('accepte l exception historique La Poste', () {
    expect(service.isValidSiretFormat('356 000 000 00001'), isTrue);
    expect(service.isValidSiretLuhn('35600000000001'), isTrue);
  });

  test('rejette les formats invalides avant tout appel distant', () async {
    await expectLater(
      service.preVerifySiret('123'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('exactement 14 chiffres'),
        ),
      ),
    );
    await expectLater(
      service.verifySiret('123'),
      throwsA(
        isA<ProSiretException>().having(
          (error) => error.message,
          'message',
          contains('exactement 14 chiffres'),
        ),
      ),
    );
  });

  test('ProSiretException expose son message', () {
    const error = ProSiretException('échec local');
    expect(error.toString(), 'échec local');
  });
}
