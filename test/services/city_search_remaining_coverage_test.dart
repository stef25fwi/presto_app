import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/city_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final search = CitySearch.instance;

  setUpAll(search.ensureLoaded);

  test('filtre tous les arrondissements Paris hors département autorisé', () {
    final results = search.search(
      'paris',
      allowedDeptCodes: const <String>['971'],
      limit: 200,
    );

    expect(
      results.where((city) => city.name.toLowerCase().startsWith('paris')),
      isEmpty,
    );
  });

  test('le classement fuzzy reste déterministe sur les égalités', () {
    for (final query in const <String>['saint', 'sainte', 'mont', 'ville']) {
      final first = search.searchFuzzy(query, limit: 200);
      final second = search.searchFuzzy(query, limit: 200);

      expect(
        second.map((city) => '${city.postalCode}|${city.name}').toList(),
        first.map((city) => '${city.postalCode}|${city.name}').toList(),
      );
    }
  });
}
