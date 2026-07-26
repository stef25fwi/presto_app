import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:presto_app/services/geo_api_gouv_service.dart';

void main() {
  group('GeoApiGouvService name search coverage', () {
    test('fromJson accepte une réponse sans liste de codes postaux', () {
      final commune = GeoApiGouvCommune.fromJson(<String, dynamic>{
        'nom': 'Commune sans CP',
        'codesPostaux': '97100',
        'codeDepartement': '971',
        'codeRegion': '01',
      });

      expect(commune.name, 'Commune sans CP');
      expect(commune.postalCodes, isEmpty);
      expect(commune.primaryPostalCode, isEmpty);
      expect(commune.matchesPostalCode(''), isTrue);
      expect(commune.matchesPostalCode('97100'), isFalse);
    });

    test('refuse une recherche trop courte sans code postal exploitable',
        () async {
      var calls = 0;
      final service = GeoApiGouvService(
        client: MockClient((request) async {
          calls += 1;
          return http.Response('[]', 200);
        }),
      );

      expect(await service.searchCommunesByName(' a '), isEmpty);
      expect(calls, 0);
    });

    test('une recherche sans nom délègue au code postal', () async {
      var calls = 0;
      final service = GeoApiGouvService(
        client: MockClient((request) async {
          calls += 1;
          expect(request.url.queryParameters['codePostal'], '97122');
          expect(request.url.queryParameters.containsKey('nom'), isFalse);
          return http.Response(
            '[{"nom":"Baie-Mahault","codesPostaux":["97122"],'
            '"codeDepartement":"971","codeRegion":"01"}]',
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      final result = await service.searchCommunesByName(
        ' ',
        postalCodeHint: '97 122',
        limit: 3,
      );

      expect(calls, 1);
      expect(result.map((entry) => entry.name), <String>['Baie-Mahault']);
    });

    test('construit la recherche par nom, filtre le département et réutilise le cache',
        () async {
      var calls = 0;
      final service = GeoApiGouvService(
        client: MockClient((request) async {
          calls += 1;
          expect(request.url.path, '/communes');
          expect(request.url.queryParameters['nom'], isNotEmpty);
          expect(request.url.queryParameters['boost'], 'population');
          expect(request.url.queryParameters['limit'], '2');
          return http.Response(
            '''
[
  {
    "nom": "Baie-Mahault",
    "codesPostaux": ["97122"],
    "codeDepartement": "971",
    "codeRegion": "01"
  },
  {
    "nom": "Fort-de-France",
    "codesPostaux": ["97122"],
    "codeDepartement": "972",
    "codeRegion": "02"
  },
  {
    "nom": "Pointe-à-Pitre",
    "codesPostaux": ["97122"],
    "codeDepartement": "971",
    "codeRegion": "01"
  }
]
''',
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      Future<List<GeoApiGouvCommune>> search() {
        return service.searchCommunesByName(
          '  Baie  ',
          postalCodeHint: '97122',
          allowedDepartmentCodes: const <String>[' 971 '],
          limit: 2,
        );
      }

      final first = await search();
      final cached = await search();

      expect(calls, 1);
      expect(first.map((entry) => entry.name), <String>['Baie-Mahault']);
      expect(cached.map((entry) => entry.name), <String>['Baie-Mahault']);
    });

    test('retourne directement les résultats sans filtre départemental',
        () async {
      final service = GeoApiGouvService(
        client: MockClient((request) async {
          return http.Response(
            '[{"nom":"Les Abymes","codesPostaux":["97139"],'
            '"codeDepartement":"971","codeRegion":"01"}]',
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      final result = await service.searchCommunesByName(
        'Les Abymes',
        allowedDepartmentCodes: const <String>[],
      );

      expect(result.map((entry) => entry.name), <String>['Les Abymes']);
    });
  });
}
