import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:presto_app/services/geo_api_gouv_service.dart';

void main() {
  group('GeoApiGouvService', () {
    test('findCommunesByPostalCode retourne une commune normalisée', () async {
      final service = GeoApiGouvService(
        client: MockClient((request) async {
          expect(request.url.path, '/communes');
          expect(request.url.queryParameters['codePostal'], '97122');

          return http.Response(
            '''
[
  {
    "nom": "Baie-Mahault",
    "code": "97103",
    "codesPostaux": ["97122"],
    "codeDepartement": "971",
    "codeRegion": "01"
  }
]
''',
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      final results = await service.findCommunesByPostalCode('97122');

      expect(results, hasLength(1));
      expect(results.first.name, 'Baie-Mahault');
      expect(results.first.inseeCode, '97103');
      expect(results.first.primaryPostalCode, '97122');
      expect(results.first.departmentCode, '971');
      expect(results.first.regionCode, '01');
    });

    test('findCommunesByPostalCode ignore un CP incomplet', () async {
      var called = false;

      final service = GeoApiGouvService(
        client: MockClient((request) async {
          called = true;
          return http.Response('[]', 200);
        }),
      );

      final results = await service.findCommunesByPostalCode('971');

      expect(results, isEmpty);
      expect(called, isFalse);
    });

    test('toFirestoreLocationFields prépare les nouveaux champs', () {
      const commune = GeoApiGouvCommune(
        name: 'Baie-Mahault',
        inseeCode: '97103',
        postalCodes: <String>['97122'],
        departmentCode: '971',
        regionCode: '01',
      );

      final fields = commune.toFirestoreLocationFields();

      expect(fields['communeName'], 'Baie-Mahault');
      expect(fields['postalCode'], '97122');
      expect(fields['departmentCode'], '971');
      expect(fields['regionCode'], '01');
      expect(fields['locationSource'], 'geo_api_gouv');
    });
  });
}
