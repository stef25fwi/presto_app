import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_photos_section.dart';
import 'package:presto_app/widgets/photo_selector_tile.dart';

void main() {
  testWidgets('affiche le quota et les tuiles de photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishOfferPhotosSection(
            visibleTileCount: 2,
            maximumPhotos: 2,
            selectedPhotos: const <XFile>[],
            selectedPhotoBytes: const <Uint8List?>[],
            onPhotoTap: (_) {},
            onPhotoLongPress: (_) {},
            onPhotoRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.text("Photos de l'offre"), findsOneWidget);
    expect(find.text('(optionnel, 2 photos maximum)'), findsOneWidget);
    expect(find.byType(PhotoSelectorTile), findsNWidgets(2));
    expect(find.text('Photo 1'), findsOneWidget);
    expect(find.text('Photo 2'), findsOneWidget);
  });

  testWidgets('transmet les interactions avec l index de la tuile',
      (tester) async {
    int? tappedIndex;
    int? longPressedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishOfferPhotosSection(
            visibleTileCount: 2,
            maximumPhotos: 2,
            selectedPhotos: const <XFile>[],
            selectedPhotoBytes: const <Uint8List?>[],
            onPhotoTap: (index) => tappedIndex = index,
            onPhotoLongPress: (index) => longPressedIndex = index,
            onPhotoRemove: (_) {},
          ),
        ),
      ),
    );

    final firstTile = find.byType(PhotoSelectorTile).first;
    await tester.tap(firstTile);
    await tester.pump();
    expect(tappedIndex, 0);

    await tester.longPress(firstTile);
    await tester.pump();
    expect(longPressedIndex, 0);
  });
}
