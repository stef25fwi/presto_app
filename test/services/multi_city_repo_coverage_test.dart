import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/multi_city_repo.dart';

ByteData _assetBytes(String value) {
  return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CityRecord', () {
    test('fromJson lit les clés canoniques', () {
      final city = CityRecord.fromJson(<String, dynamic>{
        'name': 'Les Abymes',
        'cp': '97139',
        'dept': '971',
        'region': 'Guadeloupe',
      });

      expect(city.name, 'Les Abymes');
      expect(city.cp, '97139');
      expect(city.dept, '971');
      expect(city.region, 'Guadeloupe');
    });

    test('fromJson accepte les alias et les valeurs numériques', () {
      final postalAlias = CityRecord.fromJson(<String, dynamic>{
        'ville': 'Paris',
        'postalCode': 75001,
        'department': 75,
      });
      final postcodeAlias = CityRecord.fromJson(<String, dynamic>{
        'city': 'Cayenne',
        'postcode': '97300',
        'dept': '973',
      });

      expect(postalAlias.name, 'Paris');
      expect(postalAlias.cp, '75001');
      expect(postalAlias.dept, '75');
      expect(postalAlias.region, isNull);
      expect(postcodeAlias.name, 'Cayenne');
      expect(postcodeAlias.cp, '97300');
      expect(postcodeAlias.dept, '973');
    });

    test('fromJson fournit des chaînes vides lorsque les clés manquent', () {
      final city = CityRecord.fromJson(<String, dynamic>{});

      expect(city.name, isEmpty);
      expect(city.cp, isEmpty);
      expect(city.dept, isEmpty);
      expect(city.region, isNull);
    });
  });

  group('MultiCityRepo.deptFromPostalCode', () {
    final repo = MultiCityRepo();

    test('retourne null pour une valeur absente ou sans code à cinq chiffres', () {
      expect(repo.deptFromPostalCode(null), isNull);
      expect(repo.deptFromPostalCode(''), isNull);
      expect(repo.deptFromPostalCode('9712'), isNull);
      expect(repo.deptFromPostalCode('code inconnu'), isNull);
    });

    test('déduit les départements métropolitains', () {
      expect(repo.deptFromPostalCode('75001'), '75');
      expect(repo.deptFromPostalCode('Adresse : 13008 Marseille'), '13');
      expect(repo.deptFromPostalCode('20100 Sartène'), '20');
    });

    test('conserve trois chiffres pour les codes 97 et 98', () {
      expect(repo.deptFromPostalCode('97139'), '971');
      expect(repo.deptFromPostalCode('97200 Fort-de-France'), '972');
      expect(repo.deptFromPostalCode('98714'), '987');
    });

    test('utilise le premier code postal complet trouvé', () {
      expect(repo.deptFromPostalCode('97139 puis 75001'), '971');
    });
  });

  group('MultiCityRepo assets et recherche', () {
    late Map<String, String> assets;
    late List<String> requestedAssets;

    setUp(() {
      assets = <String, String>{
        'AssetManifest.json': jsonEncode(<String, dynamic>{
          'assets/data/cities_971.json': <String>[
            'assets/data/cities_971.json',
          ],
          'assets/data/cities-75.json': <String>[
            'assets/data/cities-75.json',
          ],
          'assets/data/not-cities.txt': <String>[
            'assets/data/not-cities.txt',
          ],
          'assets/other/cities_972.json': <String>[
            'assets/other/cities_972.json',
          ],
        }),
        'assets/data/cities_971.json': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Les Abymes',
            'cp': '97139',
            'dept': '971',
            'region': 'Guadeloupe',
          },
          <String, dynamic>{
            'name': 'Pointe-à-Pitre',
            'cp': '97110',
            'dept': '971',
          },
          <String, dynamic>{
            'name': '',
            'cp': '97100',
            'dept': '971',
          },
          <String, dynamic>{
            'ville': 'Baie-Mahault',
            'postalCode': '97122',
            'department': '971',
          },
        ]),
        'assets/data/cities-75.json': jsonEncode(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Paris',
              'cp': '75001',
              'dept': '75',
            },
            <String, dynamic>{
              'name': 'Paris 08',
              'cp': '75008',
              'dept': '75',
            },
          ],
        }),
      };
      requestedAssets = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        final key = utf8.decode(message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ));
        requestedAssets.add(key);
        final value = assets[key];
        return value == null ? null : _assetBytes(value);
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('listCityAssets filtre trie et met en cache le manifeste', () async {
      final repo = MultiCityRepo();

      final first = await repo.listCityAssets();
      final second = await repo.listCityAssets();

      expect(
        first,
        <String>[
          'assets/data/cities-75.json',
          'assets/data/cities_971.json',
        ],
      );
      expect(second, same(first));
      expect(
        requestedAssets.where((path) => path == 'AssetManifest.json').length,
        1,
      );
    });

    test('loadDept charge une liste, ignore les villes vides puis utilise le cache',
        () async {
      final repo = MultiCityRepo();

      final first = await repo.loadDept('971');
      final second = await repo.loadDept('971');

      expect(first.map((city) => city.name),
          <String>['Les Abymes', 'Pointe-à-Pitre', 'Baie-Mahault']);
      expect(first.first.region, 'Guadeloupe');
      expect(second, same(first));
      expect(
        requestedAssets
            .where((path) => path == 'assets/data/cities_971.json')
            .length,
        1,
      );
    });

    test('loadDept accepte le wrapper data et mémorise un département absent',
        () async {
      final repo = MultiCityRepo();

      final paris = await repo.loadDept('75');
      final missingFirst = await repo.loadDept('972');
      final beforeSecondMissing = requestedAssets.length;
      final missingSecond = await repo.loadDept('972');

      expect(paris.map((city) => city.name), <String>['Paris', 'Paris 08']);
      expect(missingFirst, isEmpty);
      expect(missingSecond, isEmpty);
      expect(requestedAssets.length, beforeSecondMissing);
    });

    test('search charge le département du CP, normalise et respecte la limite',
        () async {
      final repo = MultiCityRepo();

      final accentInsensitiveByPunctuation = await repo.search(
        'pointe a pitre',
        cpHint: '97110',
      );
      final limited = await repo.search('paris', cpHint: '75001', limit: 1);

      expect(accentInsensitiveByPunctuation, isEmpty);
      final punctuationMatch = await repo.search(
        'pointe-à-pitre',
        cpHint: '97110',
      );
      expect(punctuationMatch.single.name, 'Pointe-à-Pitre');
      expect(limited, hasLength(1));
      expect(limited.single.name, 'Paris');
    });

    test('search sans CP réutilise uniquement les départements déjà chargés',
        () async {
      final repo = MultiCityRepo();
      await repo.loadDept('971');

      final abymes = await repo.search('  LES   ABYMES ');
      final partial = await repo.search('maha');
      final unknown = await repo.search('Paris');

      expect(abymes.single.name, 'Les Abymes');
      expect(partial.single.name, 'Baie-Mahault');
      expect(unknown, isEmpty);
    });
  });

  test('search retourne immédiatement une liste vide pour une requête vide',
      () async {
    final repo = MultiCityRepo();

    expect(await repo.search(''), isEmpty);
    expect(await repo.search('   '), isEmpty);
  });
}
