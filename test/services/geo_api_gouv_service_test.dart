import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:presto_app/services/geo_api_gouv_service.dart';

void main() {
  group('GeoApiGouvCommune', () {
    test('normalizes JSON fields and exposes Firestore location fields', () {
      final commune = GeoApiGouvCommune.fromJson(<String, dynamic>{
        'nom': 'Les Abymes',
        'codesPostaux': <dynamic>['97139', 97142],
        'codeDepartement': '971',
        'codeRegion': 1,
      });

      expect(commune.name, 'Les Abymes');
      expect(commune.postalCodes, <String>['97139', '97142']);
      expect(commune.departmentCode, '971');
      expect(commune.regionCode, '1');
      expect(commune.primaryPostalCode, '97139');
      expect(commune.matchesPostalCode(' 97142 '), isTrue);
      expect(commune.matchesPostalCode(''), isTrue);
      expect(commune.matchesPostalCode('75001'), isFalse);
      expect(
        commune.toFirestoreLocationFields(locationSource: 'test_source'),
        <String, dynamic>{
          'communeName': 'Les Abymes',
          'postalCode': '97139',
          'departmentCode': '971',
          'regionCode': '1',
          'locationSource': 'test_source',
        },
      );
    });

    test('uses safe defaults for missing or invalid fields', () {
      final commune = GeoApiGouvCommune.fromJson(<String, dynamic>{
        'codesPostaux': '97100',
      });

      expect(commune.name, isEmpty);
      expect(commune.postalCodes, isEmpty);
      expect(commune.primaryPostalCode, isEmpty);
      expect(commune.departmentCode, isEmpty);
      expect(commune.regionCode, isEmpty);
      expect(
        commune.toFirestoreLocationFields()['locationSource'],
        'geo_api_gouv',
      );
    });
  });

  group('GeoApiGouvService', () {
    test('rejects invalid postal codes without calling HTTP', () async {
      var calls = 0;
      final service = GeoApiGouvService(
        client: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );

      expect(await service.findCommunesByPostalCode('971'), isEmpty);
      expect(calls, 0);
      service.close();
    });

    test('normalizes postal code, filters results, applies limit and caches', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/communes');
        expect(request.url.queryParameters['codePostal'], '97139');
        expect(request.url.queryParameters['format'], 'json');
        return http.Response.bytes(
          utf8.encode(jsonEncode(<Object?>[
            <String, dynamic>{
              'nom': 'Les Abymes',
              'codesPostaux': <String>['97139'],
              'codeDepartement': '971',
              'codeRegion': '01',
            },
            <String, dynamic>{
              'nom': '',
              'codesPostaux': <String>['97139'],
              'codeDepartement': '971',
              'codeRegion': '01',
            },
            <String, dynamic>{
              'nom': 'Pointe-a-Pitre',
              'codesPostaux': <String>['97110'],
              'codeDepartement': '971',
              'codeRegion': '01',
            },
            <String, dynamic>{
              'nom': 'Baie-Mahault',
              'codesPostaux': <String>['97139'],
              'codeDepartement': '971',
              'codeRegion': '01',
            },
          ])),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      });
      final service = GeoApiGouvService(client: client);

      final first = await service.findCommunesByPostalCode('97 139', limit: 1);
      final second = await service.findCommunesByPostalCode('97139', limit: 1);

      expect(first.map((e) => e.name), <String>['Les Abymes']);
      expect(second.map((e) => e.name), <String>['Les Abymes']);
      expect(calls, 1);
      service.close();
    });

    test('searches by name and filters allowed departments', () async {
      final service = GeoApiGouvService(
        client: MockClient((request) async {
          expect(request.url.queryParameters['nom'], 'Saint');
          expect(request.url.queryParameters['boost'], 'population');
          expect(request.url.queryParameters['limit'], '5');
          return http.Response(
            jsonEncode(<Object?>[
              <String, dynamic>{
                'nom': 'Saint-Claude',
                'codesPostaux': <String>['97120'],
                'codeDepartement': '971',
                'codeRegion': '01',
              },
              <String, dynamic>{
                'nom': 'Saint-Pierre',
                'codesPostaux': <String>['97250'],
                'codeDepartement': '972',
                'codeRegion': '02',
              },
            ]),
            200,
          );
        }),
      );

      final results = await service.searchCommunesByName(
        '  Saint  ',
        allowedDepartmentCodes: <String>[' 972 '],
        limit: 5,
      );

      expect(results.map((e) => e.name), <String>['Saint-Pierre']);
      service.close();
    });

    test('returns unfiltered results when allowed departments are absent', () async {
      final service = GeoApiGouvService(
        client: MockClient((_) async => http.Response(
              jsonEncode(<Object?>[
                <String, dynamic>{
                  'nom': 'Paris',
                  'codesPostaux': <String>['75001'],
                  'codeDepartement': '75',
                  'codeRegion': '11',
                },
              ]),
              200,
            )),
      );

      expect((await service.searchCommunesByName('Paris')).single.name, 'Paris');
      expect(
        (await service.searchCommunesByName(
          'Lyon',
          allowedDepartmentCodes: const <String>[],
        )),
        isNotNull,
      );
      service.close();
    });

    test('delegates short name search to postal-code lookup when hint is valid', () async {
      var calls = 0;
      final service = GeoApiGouvService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters['codePostal'], '97139');
          expect(request.url.queryParameters.containsKey('nom'), isFalse);
          return http.Response(
            jsonEncode(<Object?>[
              <String, dynamic>{
                'nom': 'Les Abymes',
                'codesPostaux': <String>['97139'],
                'codeDepartement': '971',
                'codeRegion': '01',
              },
            ]),
            200,
          );
        }),
      );

      final results = await service.searchCommunesByName(
        'x',
        postalCodeHint: '971-39',
      );

      expect(results.single.name, 'Les Abymes');
      expect(calls, 1);
      service.close();
    });

    test('returns empty for insufficient search input', () async {
      var calls = 0;
      final service = GeoApiGouvService(
        client: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );

      expect(
        await service.searchCommunesByName('x', postalCodeHint: '971'),
        isEmpty,
      );
      expect(calls, 0);
      service.close();
    });

    test('returns empty on non-200, malformed shape, invalid JSON and client error', () async {
      final non200 = GeoApiGouvService(
        client: MockClient((_) async => http.Response('nope', 503)),
      );
      expect(await non200.searchCommunesByName('ab'), isEmpty);

      final wrongShape = GeoApiGouvService(
        client: MockClient((_) async => http.Response('{"ok":true}', 200)),
      );
      expect(await wrongShape.searchCommunesByName('ab'), isEmpty);

      final invalidJson = GeoApiGouvService(
        client: MockClient((_) async => http.Response('{', 200)),
      );
      expect(await invalidJson.searchCommunesByName('ab'), isEmpty);

      final throwing = GeoApiGouvService(
        client: MockClient((_) async => throw StateError('network failure')),
      );
      expect(await throwing.searchCommunesByName('ab'), isEmpty);

      non200.close();
      wrongShape.close();
      invalidJson.close();
      throwing.close();
    });

    test('joins a base path correctly', () async {
      late Uri requested;
      final service = GeoApiGouvService(
        baseUri: Uri.parse('https://example.test/api/'),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response('[]', 200);
        }),
      );

      await service.searchCommunesByName('Paris');

      expect(requested.path, '/api/communes');
      service.close();
    });
  });
}
