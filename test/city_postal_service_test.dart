import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/geo_api_gouv_service.dart';
import 'package:presto_app/widgets/city_postal_autocomplete_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('city entries normalize JSON and Paris display names', () {
    final first = CityEntry.fromJson(<String, dynamic>{
      'name': 'PARIS 01',
      'dept': '75',
      'cps': <String>['75001'],
    });
    final second = CityEntry.fromJson(<String, dynamic>{
      'name': 'PARIS 02',
      'dept': 75,
      'cps': <dynamic>[75002],
    });
    final regular = CityEntry.fromJson(<String, dynamic>{
      'name': 'Les Abymes',
      'dept': '971',
    });

    expect(first.displayName, 'Paris 1er arrondissement');
    expect(second.displayName, 'Paris 2e arrondissement');
    expect(second.dept, '75');
    expect(second.cps, <String>['75002']);
    expect(regular.displayName, 'Les Abymes');
    expect(regular.cps, isEmpty);
    expect(regular.nameNorm, 'les abymes');
  });

  test('city entries convert Geo API communes', () {
    const commune = GeoApiGouvCommune(
      name: 'Pointe-à-Pitre',
      postalCodes: <String>['97110'],
      departmentCode: '971',
      regionCode: '01',
    );
    final entry = CityEntry.fromGeoApiGouv(commune);

    expect(entry.name, 'Pointe-à-Pitre');
    expect(entry.dept, '971');
    expect(entry.cps, <String>['97110']);
    expect(entry.nameNorm, 'pointe a pitre');
  });

  test('local service initializes once and searches by prefix and contains',
      () async {
    final service = CityPostalService();
    await service.init();
    await service.init();

    final prefix = service.search('Les Abymes', limit: 10);
    expect(prefix, isNotEmpty);
    expect(prefix.first.name.toLowerCase(), contains('abymes'));

    final containsResults = service.search('abym', limit: 10);
    expect(containsResults, isNotEmpty);
    expect(containsResults.length, lessThanOrEqualTo(10));
    expect(service.search('   '), isEmpty);
  });

  test('Paris alias respects the requested limit and removes duplicates',
      () async {
    final service = CityPostalService();
    await service.init();

    final results = service.search('paris', limit: 3);
    expect(results, hasLength(3));
    expect(results.every((entry) => entry.nameNorm.startsWith('paris')), isTrue);
    expect(results.map((entry) => '${entry.name}|${entry.dept}').toSet(),
        hasLength(3));
  });

  test('postal hint filters mainland, overseas and Corsica departments',
      () async {
    final service = CityPostalService();
    await service.init();

    final guadeloupe = service.search(
      'abymes',
      cpHint: 'code 97139',
      limit: 20,
    );
    expect(guadeloupe, isNotEmpty);
    expect(guadeloupe.every((entry) => entry.dept == '971'), isTrue);

    final paris = service.search('paris', cpHint: '75001', limit: 20);
    expect(paris, isNotEmpty);
    expect(paris.every((entry) => entry.dept == '75'), isTrue);

    final corse = service.search('ajaccio', cpHint: '20000', limit: 20);
    expect(corse.every((entry) => entry.dept == '2A' || entry.dept == '2B'),
        isTrue);
  });

  test('finds cities by postal code with optional department filtering',
      () async {
    final service = CityPostalService();
    await service.init();

    final found = service.findByPostalCode('97139');
    expect(found, isNotNull);
    expect(found!.dept, '971');
    expect(found.cps, contains('97139'));
    expect(service.findByPostalCode('97139', dept: '972'), isNull);
    expect(service.findByPostalCode(''), isNull);
    expect(service.findByPostalCode('00000'), isNull);
  });

  test('search safely returns no results before initialization', () {
    final service = CityPostalService();
    expect(service.search('Paris'), isEmpty);
    expect(service.findByPostalCode('75001'), isNull);
  });
}
