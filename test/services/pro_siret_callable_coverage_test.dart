import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/pro_siret_service.dart';

void main() {
  group('ProSiretService callable coverage', () {
    test('accepte l exception historique La Poste', () {
      final service = ProSiretService(caller: (_, __) async => const {});

      expect(service.isValidSiretLuhn('35600000000001'), isTrue);
      expect(service.isValidSiretLuhn('35600000000002'), isFalse);
    });

    test('preVerifySiret nettoie la valeur et convertit la réponse', () async {
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
      expect(result.leaderDeclaredMatch, isFalse);
    });

    test('preVerifySiret rejette une réponse non Map', () async {
      final service = ProSiretService(
        caller: (_, __) async => 'réponse invalide',
      );

      await expectLater(
        service.preVerifySiret('73282932000074'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Réponse SIRET invalide'),
          ),
        ),
      );
    });

    test('verifySiret transmet le dirigeant déclaré et convertit la réponse', () async {
      String? calledName;
      Map<String, dynamic>? calledParameters;
      final service = ProSiretService(
        caller: (name, parameters) async {
          calledName = name;
          calledParameters = parameters;
          return <Object?, Object?>{
            'ok': true,
            'siret': '73282932000074',
            'companyName': 'Société vérifiée',
            'leaderDeclaredMatch': true,
            'declaredLeaderFirstName': 'Marie',
            'declaredLeaderLastName': 'Dupont',
            'declaredLeaderRole': 'Présidente',
            'verificationLevel': 'siret_declared_leader_match',
            'proStatus': 'verified_siret_leader_match',
          };
        },
      );

      final result = await service.verifySiret(
        '73282932000074',
        leaderFirstName: ' Marie ',
        leaderLastName: ' Dupont ',
      );

      expect(calledName, 'verifySiret');
      expect(calledParameters, <String, dynamic>{
        'siret': '73282932000074',
        'leaderFirstName': 'Marie',
        'leaderLastName': 'Dupont',
      });
      expect(result.ok, isTrue);
      expect(result.companyName, 'Société vérifiée');
      expect(result.leaderDeclaredMatch, isTrue);
      expect(result.declaredLeaderRole, 'Présidente');
      expect(result.proStatus, 'verified_siret_leader_match');
    });

    test('verifySiret exige le nom et prénom du dirigeant', () async {
      final service = ProSiretService(caller: (_, __) async => const {});

      await expectLater(
        service.verifySiret(
          '73282932000074',
          leaderFirstName: '',
          leaderLastName: 'Dupont',
        ),
        throwsA(
          isA<ProSiretException>().having(
            (error) => error.message,
            'message',
            contains('nom et le prénom'),
          ),
        ),
      );
    });

    test('verifySiret traduit une erreur Firebase Functions', () async {
      final service = ProSiretService(
        caller: (_, __) async => throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Service SIRET indisponible',
        ),
      );

      await expectLater(
        service.verifySiret(
          '73282932000074',
          leaderFirstName: 'Marie',
          leaderLastName: 'Dupont',
        ),
        throwsA(
          isA<ProSiretException>().having(
            (error) => error.message,
            'message',
            'Service SIRET indisponible',
          ),
        ),
      );
    });
  });
}
