import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/features/offers/domain/publish_offer_draft_policy.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_photos_section.dart';
import 'package:presto_app/pages/publish_offer_widgets.dart';
import 'package:presto_app/widgets/photo_selector_tile.dart';

void main() {
  group('PublishOfferDraftPolicy urgency vocabulary', () {
    const phrases = <String>[
      'Intervention sous 48h',
      'Intervention cette semaine',
      'Intervention rapidement',
      'Intervention dès que possible',
      'Intervention des que possible',
    ];

    for (final phrase in phrases) {
      test('reconnaît "$phrase" comme une urgence', () {
        expect(
          PublishOfferDraftPolicy.transcriptMentionsUrgency(phrase),
          isTrue,
        );
      });
    }
  });

  testWidgets('construit les tuiles photo et transmet chaque interaction',
      (tester) async {
    final taps = <int>[];
    final longPresses = <int>[];
    final removals = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishOfferPhotosSection(
            visibleTileCount: 2,
            maximumPhotos: 2,
            selectedPhotos: <XFile>[XFile('/tmp/selected.jpg')],
            selectedPhotoBytes: <Uint8List?>[null],
            onPhotoTap: taps.add,
            onPhotoLongPress: longPresses.add,
            onPhotoRemove: removals.add,
          ),
        ),
      ),
    );

    final tiles = tester.widgetList<PhotoSelectorTile>(
      find.byType(PhotoSelectorTile),
    ).toList();
    expect(tiles, hasLength(2));
    expect(tiles.first.file?.path, '/tmp/selected.jpg');
    expect(tiles.first.bytes, isNull);
    expect(tiles.first.onRemove, isNotNull);
    expect(tiles.last.file, isNull);
    expect(tiles.last.onRemove, isNull);

    tiles.first.onTap();
    tiles.first.onLongPress?.call();
    tiles.first.onRemove?.call();
    tiles.last.onTap();
    tiles.last.onLongPress?.call();

    expect(taps, <int>[0, 1]);
    expect(longPresses, <int>[0, 1]);
    expect(removals, <int>[0]);
  });

  testWidgets('le bouton fermer retire le diagnostic IA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => PublishAiTraceDiagnosticDialog(
                  entries: const <PublishAiTraceEntry>[],
                  runtimeState: 'idle',
                  latestTranscript: '',
                  onClear: () {},
                ),
              );
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnostic micro IA'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnostic micro IA'), findsNothing);
  });
}
