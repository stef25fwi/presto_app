import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_models.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_page_operations.dart';
import 'package:presto_app/pages/admin_videomaker_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required VideoMakerVideosLoader loadVideos,
    VideoMakerImagePicker? pickImage,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminVideoMakerPage(
          loadVideos: loadVideos,
          pickImage: pickImage,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition,
  ) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue);
  }

  testWidgets('affiche l erreur de chargement puis permet une actualisation',
      (tester) async {
    var calls = 0;
    await pumpPage(
      tester,
      loadVideos: () async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return const <GeneratedVideo>[];
      },
    );

    await pumpUntil(
      tester,
      () => find
          .text('Impossible de charger la bibliothèque de vidéos.')
          .evaluate()
          .isNotEmpty,
    );
    expect(calls, 1);

    await tester.tap(find.byTooltip('Actualiser la bibliothèque'));
    await pumpUntil(tester, () => calls == 2);
    expect(find.text('Aucune vidéo générée'), findsOneWidget);
  });

  testWidgets('refuse une image vide', (tester) async {
    await pumpPage(
      tester,
      loadVideos: () async => const <GeneratedVideo>[],
      pickImage: () async => <VideoMakerSelectedImage>[
        VideoMakerSelectedImage(
          bytes: Uint8List(0),
          name: 'vide.png',
          mimeType: 'image/png',
        ),
      ],
    );

    await pumpUntil(
      tester,
      () => find.text('Aucune vidéo générée').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Choisir plusieurs images'));
    await pumpUntil(
      tester,
      () => find
          .text('vide.png doit être valide et peser moins de 5 Mo.')
          .evaluate()
          .isNotEmpty,
    );
  });

  testWidgets('refuse un type image non pris en charge', (tester) async {
    await pumpPage(
      tester,
      loadVideos: () async => const <GeneratedVideo>[],
      pickImage: () async => <VideoMakerSelectedImage>[
        VideoMakerSelectedImage(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          name: 'reference.bmp',
          mimeType: 'image/bmp',
        ),
      ],
    );

    await pumpUntil(
      tester,
      () => find.text('Aucune vidéo générée').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Choisir plusieurs images'));
    await pumpUntil(
      tester,
      () => find
          .text('reference.bmp : utilisez JPG, PNG, WEBP, HEIC ou HEIF.')
          .evaluate()
          .isNotEmpty,
    );
  });

  testWidgets('transforme une exception du sélecteur en message utilisateur',
      (tester) async {
    await pumpPage(
      tester,
      loadVideos: () async => const <GeneratedVideo>[],
      pickImage: () async => throw StateError('picker unavailable'),
    );

    await pumpUntil(
      tester,
      () => find.text('Aucune vidéo générée').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Choisir plusieurs images'));
    await pumpUntil(
      tester,
      () => find
          .text('Impossible de sélectionner ces images.')
          .evaluate()
          .isNotEmpty,
    );
  });
}
