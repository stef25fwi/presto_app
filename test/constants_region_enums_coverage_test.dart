import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/constants.dart';
import 'package:presto_app/models/marketplace_enums.dart';

void main() {
  group('marketplace enum parsing', () {
    test('round-trips every listing, moderation and visibility value', () {
      for (final status in ListingStatus.values) {
        expect(ListingStatusParsing.fromString(status.value), status);
      }
      for (final status in ModerationStatus.values) {
        expect(ModerationStatusParsing.fromString(status.value), status);
      }
      for (final visibility in ListingVisibility.values) {
        expect(ListingVisibilityParsing.fromString(visibility.value), visibility);
      }

      expect(ListingStatusParsing.fromString(' unknown '), ListingStatus.draft);
      expect(
        ModerationStatusParsing.fromString(' unknown '),
        ModerationStatus.pending,
      );
      expect(
        ListingVisibilityParsing.fromString(' unknown '),
        ListingVisibility.private,
      );
    });

    test('expose toutes les raisons de signalement sérialisées', () {
      expect(
        ListingReportReasonCode.values.map((reason) => reason.value).toList(),
        <String>[
          'spam',
          'fraud',
          'inappropriate',
          'duplicate',
          'wrong_category',
          'fake_listing',
          'harassment',
          'other',
        ],
      );
    });
  });

  group('region constants', () {
    test('normalise accents, apostrophes et espaces', () {
      expect(normalizeRegionKey(' Île-de-France '), 'ile-de-france');
      expect(
        normalizeRegionKey("Provence-Alpes-Côte d'Azur"),
        'provence-alpes-cote-dazur',
      );
      expect(normalizeRegionKey('La Réunion'), 'la-reunion');
      expect(normalizeRegionKey('GUADELOUPE'), 'guadeloupe');
    });

    test('retrouve les libellés et trie métropole puis DROM', () {
      expect(regionDisplayName('guadeloupe'), 'Guadeloupe');
      expect(regionDisplayName('inconnue'), isNull);

      final sorted = getRegionsSorted();
      final firstDrom = sorted.indexWhere((region) => region.isDrom);
      expect(firstDrom, greaterThan(0));
      expect(sorted.take(firstDrom).every((region) => !region.isDrom), isTrue);
      expect(sorted.skip(firstDrom).every((region) => region.isDrom), isTrue);
      expect(sorted.first.code, '11');
      expect(sorted[firstDrom].code, '01');

      const guadeloupe = RegionItem(
        code: '01',
        name: 'Guadeloupe',
        isDrom: true,
      );
      expect(guadeloupe.label, '01 — Guadeloupe');
      expect(guadeloupe.normalizedKey, 'guadeloupe');
      expect(kRegionDepartments['01'], contains('971'));
    });

    testWidgets('construit le dropdown et transmet une sélection DROM', (
      tester,
    ) async {
      RegionItem? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: buildRegionDropdown(
                value: null,
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Région'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<RegionItem>));
      await tester.pumpAndSettle();

      expect(find.text('France métropolitaine'), findsOneWidget);
      expect(find.text('DROM'), findsOneWidget);
      expect(find.text('01 — Guadeloupe'), findsOneWidget);

      await tester.tap(find.text('01 — Guadeloupe').last);
      await tester.pumpAndSettle();

      expect(selected?.name, 'Guadeloupe');
      expect(selected?.isDrom, isTrue);
    });
  });
}
