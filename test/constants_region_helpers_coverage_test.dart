import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/constants.dart';

void main() {
  test('normalizeRegionKey retire accents espaces et apostrophes', () {
    expect(normalizeRegionKey(' Île-de-France '), 'ile-de-france');
    expect(
      normalizeRegionKey("Provence-Alpes-Côte d'Azur"),
      'provence-alpes-cote-dazur',
    );
    expect(normalizeRegionKey('La Réunion'), 'la-reunion');
    expect(normalizeRegionKey('Bourgogne–Franche Comté'),
        'bourgogne–franche-comte');
  });

  test('regionDisplayName retrouve les régions et retourne null sinon', () {
    expect(regionDisplayName('guadeloupe'), 'Guadeloupe');
    expect(regionDisplayName('martinique'), 'Martinique');
    expect(regionDisplayName('ile-de-france'), 'Île-de-France');
    expect(regionDisplayName('inconnue'), isNull);
  });

  test('RegionItem expose label et clé normalisée', () {
    const region = RegionItem(
      code: '01',
      name: 'Guadeloupe',
      isDrom: true,
    );

    expect(region.label, '01 — Guadeloupe');
    expect(region.normalizedKey, 'guadeloupe');
    expect(region.isDrom, isTrue);
  });

  test('getRegionsSorted place la métropole avant les DROM', () {
    final regions = getRegionsSorted();
    final firstDrom = regions.indexWhere((region) => region.isDrom);

    expect(regions, hasLength(kRegionsOrdered.length));
    expect(firstDrom, greaterThan(0));
    expect(regions.take(firstDrom).every((region) => !region.isDrom), isTrue);
    expect(regions.skip(firstDrom).every((region) => region.isDrom), isTrue);
    expect(regions.first.code, '11');
    expect(regions[firstDrom].code, '01');
    expect(regions.last.code, '06');
  });

  test('les mappings DROM conservent leurs départements officiels', () {
    expect(kRegionDepartments['01'], const <String>['971']);
    expect(kRegionDepartments['02'], const <String>['972']);
    expect(kRegionDepartments['03'], const <String>['973']);
    expect(kRegionDepartments['04'], const <String>['974']);
    expect(kRegionDepartments['06'], const <String>['976']);
  });
}
