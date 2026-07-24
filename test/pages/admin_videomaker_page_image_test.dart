import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_models.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_page_operations.dart';
import 'package:presto_app/pages/admin_videomaker_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    VideoMakerImagePicker picker,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminVideoMakerPage(
          loadVideos: () async => const <GeneratedVideo>[],
          pickImage: picker,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Widget attendu introuvable après traitement asynchrone: $finder');
  }

  Finder pickButton() =>
      find.text('Ajouter une image de départ (facultatif)');

  testWidgets('refuse une image vide', (tester) async {
    await pumpPage(
      tester,
      () async => <VideoMakerSelectedImage>[
        VideoMakerSelectedImage(
          bytes: Uint8List(0),
          name: 'vide.png',
          mimeType: 'image/png',
        ),
      ],
    );

    await tester.tap(pickButton());
    await pumpUntilFound(
      tester,
      find.text('L’image doit être valide et peser moins de 5 Mo.'),
    );
  });

  testWidgets('refuse un format d’image non pris en charge', (tester) async {
    await pumpPage(
      tester,
      () async => <VideoMakerSelectedImage>[
        VideoMakerSelectedImage(
          bytes: Uint8List.fromList(<int>[1]),
          name: 'animation.gif',
          mimeType: 'image/gif',
        ),
      ],
    );

    await tester.tap(pickButton());
    await pumpUntilFound(
      tester,
      find.text('Utilisez une image JPG, PNG, WEBP, HEIC ou HEIF.'),
    );
  });

  testWidgets('signale une erreur du sélecteur d’image', (tester) async {
    await pumpPage(
      tester,
      () async => throw StateError('sélection indisponible'),
    );

    await tester.tap(pickButton());
    await pumpUntilFound(
      tester,
      find.text('Impossible de sélectionner cette image.'),
    );
  });
}
