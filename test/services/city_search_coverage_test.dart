import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/city_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final search = CitySearch.instance;

  setUpAll(search.ensureLoaded);

  test('CityRecord expose ses adaptateurs historiques', () {
    final city = CityRecord(
      name: 'Baie-Mahault',
      postalCode: '97122',
      departmentCode: '971',
      regionCode: '01',
    );

    expect(city.cp, '97122');
    expect(city.dept, '971');
    expect(city.region, '01');
  });

  test('les recherches vides restent sans résultat', () async {
    expect(search.search('   '), isEmpty);
    expect(await search.searchByNamePrefix('  '), isEmpty);
    expect(await search.searchByPostalPrefix('  '), isEmpty);
    expect(await search.searchSuggestions('  '), isEmpty);
    expect(search.searchByPostalCode('  '), isEmpty);
    expect(search.searchFuzzy('  '), isEmpty);
    expect(search.pickBestForPostalCode('  '), isNull);
  });

  test('les recherches par nom et code postal utilisent le bon contrat',
      () async {
    final byName = await search.searchByNamePrefix('mel');
    final byPostal = await search.searchByPostalPrefix('770');
    final nameSuggestion = await search.searchSuggestions('mel');
    final postalSuggestion = await search.searchSuggestions('770');

    expect(byName.any((city) => city.name == 'Melun'), isTrue);
    expect(byPostal, isNotEmpty);
    expect(byPostal.every((city) => city.postalCode.startsWith('770')), isTrue);
    expect(nameSuggestion.any((city) => city.name == 'Melun'), isTrue);
    expect(postalSuggestion, isNotEmpty);
    expect(
      postalSuggestion.every((city) => city.postalCode.startsWith('770')),
      isTrue,
    );
  });

  test('la recherche normalise espaces, tirets et apostrophes', () {
    final melun = search.search("m-e l'un");
    expect(melun.any((city) => city.name == 'Melun'), isTrue);
  });

  test('Paris exécute son alias et respecte la limite', () {
    final paris = search.search('paris', limit: 3);

    expect(paris.length, lessThanOrEqualTo(3));
    expect(paris.every((city) => city.name.startsWith('Paris')), isTrue);
  });

  test('le filtre départemental accepte et refuse Melun', () {
    final accepted = search.search(
      'melun',
      allowedDeptCodes: const <String>['77'],
    );
    final refused = search.search(
      'melun',
      allowedDeptCodes: const <String>['971'],
    );

    expect(accepted.any((city) => city.name == 'Melun'), isTrue);
    expect(refused.any((city) => city.name == 'Melun'), isFalse);
  });

  test('contains complète les résultats après startsWith', () {
    final results = search.search('elun', limit: 10);
    expect(results.any((city) => city.name == 'Melun'), isTrue);
  });

  test('recherche postale, sélection exacte et préfixe sont cohérentes', () {
    final postal = search.searchByPostalCode('770');
    final exact = search.pickBestForPostalCode('77000');
    final prefix = search.pickBestForPostalCode('770');

    expect(postal, isNotEmpty);
    expect(postal.every((city) => city.postalCode.startsWith('770')), isTrue);
    expect(exact, isNotNull);
    expect(exact!.postalCode, '77000');
    expect(prefix, isNotNull);
    expect(prefix!.postalCode.startsWith('770'), isTrue);
    expect(search.pickBestForPostalCode('00000'), isNull);
  });

  test('la recherche floue classe les correspondances et filtre le CP', () {
    final exact = search.searchFuzzy('Melun');
    final typo = search.searchFuzzy('Melunx');
    final matchingPostal = search.searchFuzzy('Melunx', postalCode: '77000');
    final wrongPostal = search.searchFuzzy('Melunx', postalCode: '97122');

    expect(exact.any((city) => city.name == 'Melun'), isTrue);
    expect(typo.any((city) => city.name == 'Melun'), isTrue);
    expect(matchingPostal.any((city) => city.name == 'Melun'), isTrue);
    expect(wrongPostal, isEmpty);
  });

  test('les limites des recherches asynchrones sont respectées', () async {
    expect(await search.searchByNamePrefix('m', limit: 1), hasLength(1));
    expect(await search.searchByPostalPrefix('7', limit: 1), hasLength(1));
  });
}
