import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/pro_siret_service.dart';

void main() {
  test('accepts the historical La Poste SIRET exception', () {
    final service = ProSiretService(caller: (_, __) async => const {});

    expect(service.isValidSiretLuhn('35600000000001'), isTrue);
  });

  test('pre-verifies through the injectable callable and parses the result',
      () async {
    String? calledName;
    Map<String, dynamic>? calledParameters;
    final service = ProSiretService(
      caller: (name, parameters) async {
        calledName = name;
        calledParameters = parameters;
        return <String, dynamic>{
          'ok': true,
          'siret': '73282932000074',
          'siren': '732829320',
          'companyName': 'Entreprise Test',
          'address': '1 rue Test',
          'postalCode': '97122',
          'city': 'Baie-Mahault',
          'nafCode': '6201Z',
          'proStatus': 'verified',
        };
      },
    );

    final result = await service.preVerifySiret('732 829 320 00074');

    expect(calledName, 'preVerifySiret');
    expect(calledParameters, <String, dynamic>{'siret': '73282932000074'});
    expect(result.ok, isTrue);
    expect(result.companyName, 'Entreprise Test');
    expect(result.city, 'Baie-Mahault');
  });

  test('rejects a non-map pre-verification response', () async {
    final service = ProSiretService(caller: (_, __) async => 'invalid');

    await expectLater(
      service.preVerifySiret('73282932000074'),
      throwsA(isA<Exception>()),
    );
  });

  test('verifies through the injectable callable', () async {
    String? calledName;
    Map<String, dynamic>? calledParameters;
    final service = ProSiretService(
      caller: (name, parameters) async {
        calledName = name;
        calledParameters = parameters;
        return <String, dynamic>{
          'ok': true,
          'siret': '73282932000074',
          'companyName': 'Entreprise vérifiée',
        };
      },
    );

    final result = await service.verifySiret('73282932000074');

    expect(calledName, 'verifySiret');
    expect(calledParameters, <String, dynamic>{'siret': '73282932000074'});
    expect(result.companyName, 'Entreprise vérifiée');
  });

  test('maps Firebase Functions errors to ProSiretException', () async {
    final service = ProSiretService(
      caller: (_, __) async => throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'Service indisponible',
      ),
    );

    await expectLater(
      service.verifySiret('73282932000074'),
      throwsA(
        isA<ProSiretException>().having(
          (error) => error.message,
          'message',
          'Service indisponible',
        ),
      ),
    );
  });
}
