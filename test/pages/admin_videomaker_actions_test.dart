import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_models.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_page_operations.dart';
import 'package:presto_app/pages/admin_videomaker_page.dart';

void main() {
  GeneratedVideo readyVideo() {
    return GeneratedVideo(
      id: 'video-ready',
      prompt: 'Portail peint en accéléré',
      status: 'ready',
      model: 'veo-3.1-generate-preview',
      aspectRatio: '16:9',
      durationSeconds: '8',
      resolution: '720p',
      referenceImageCount: 0,
      referenceImageNames: const <String>[],
      publicUrl: 'https://example.test/video.mp4',
      fileName: 'video.mp4',
      sizeBytes: 1024,
      createdAt: DateTime.utc(2026, 7, 17),
      generatedAt: DateTime.utc(2026, 7, 17),
      errorMessage: null,
    );
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    String reason = 'condition asynchrone non atteinte',
  }) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 20));
    }
    fail(reason);
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required Future<List<GeneratedVideo>> Function() loadVideos,
    Future<bool> Function(Uri uri)? openVideo,
    Future<bool> Function(GeneratedVideo video, Rect? origin)? shareVideo,
    VideoMakerImagePicker? pickImage,
    Finder? expected,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminVideoMakerPage(
          loadVideos: loadVideos,
          openVideo: openVideo,
          shareVideo: shareVideo,
          pickImage: pickImage,
        ),
      ),
    );
    final target = expected ?? find.text('Ouvrir');
    await pumpUntil(
      tester,
      () => target.evaluate().isNotEmpty,
      reason: 'état Videomaker attendu introuvable: $target',
    );
  }

  testWidgets('ouvre le lien de téléchargement injecté', (tester) async {
    Uri? openedUri;
    await pumpPage(
      tester,
      loadVideos: () async => <GeneratedVideo>[readyVideo()],
      openVideo: (uri) async {
        openedUri = uri;
        return true;
      },
    );

    await tester.tap(find.text('Ouvrir'));
    await pumpUntil(tester, () => openedUri != null);

    expect(openedUri, Uri.parse('https://example.test/video.mp4'));
    expect(find.text('Impossible d’ouvrir cette vidéo.'), findsNothing);
  });

  testWidgets('signale un téléchargement impossible', (tester) async {
    await pumpPage(
      tester,
      loadVideos: () async => <GeneratedVideo>[readyVideo()],
      openVideo: (_) async => false,
    );

    await tester.tap(find.text('Ouvrir'));
    await pumpUntil(
      tester,
      () => find.text('Impossible d’ouvrir cette vidéo.').evaluate().isNotEmpty,
    );

    expect(find.text('Impossible d’ouvrir cette vidéo.'), findsOneWidget);
  });

  testWidgets('partage le lien lorsque le fichier ne peut pas être joint',
      (tester) async {
    GeneratedVideo? sharedVideo;
    Rect? sharedOrigin;
    await pumpPage(
      tester,
      loadVideos: () async => <GeneratedVideo>[readyVideo()],
      shareVideo: (video, origin) async {
        sharedVideo = video;
        sharedOrigin = origin;
        return false;
      },
    );

    await tester.tap(find.text('Partager'));
    await pumpUntil(
      tester,
      () => find
          .text(
            'Le fichier n’a pas pu être joint : le lien vidéo a été partagé.',
          )
          .evaluate()
          .isNotEmpty,
    );

    expect(sharedVideo?.id, 'video-ready');
    expect(sharedOrigin, isNotNull);
  });

  testWidgets('empêche deux partages simultanés de la même vidéo',
      (tester) async {
    final completer = Completer<bool>();
    var calls = 0;
    await pumpPage(
      tester,
      loadVideos: () async => <GeneratedVideo>[readyVideo()],
      shareVideo: (_, __) {
        calls++;
        return completer.future;
      },
    );

    await tester.tap(find.text('Partager'));
    await pumpUntil(tester, () => calls == 1);
    await tester.tap(find.text('Partager'));
    await tester.pump();

    expect(calls, 1);
    completer.complete(true);
    await tester.pump();
  });

  testWidgets('ignore proprement une sélection d’image annulée',
      (tester) async {
    var pickerCalled = false;
    await pumpPage(
      tester,
      loadVideos: () async => const <GeneratedVideo>[],
      pickImage: () async {
        pickerCalled = true;
        return const <VideoMakerSelectedImage>[];
      },
      expected: find.text('Aucune vidéo générée'),
    );

    await tester.tap(find.text('Choisir plusieurs images'));
    await pumpUntil(tester, () => pickerCalled);

    expect(find.text('Image de départ'), findsNothing);
    expect(find.text('Impossible de sélectionner ces images.'), findsNothing);
  });

  testWidgets('refuse une image dépassant cinq mégaoctets', (tester) async {
    await pumpPage(
      tester,
      loadVideos: () async => const <GeneratedVideo>[],
      pickImage: () async => <VideoMakerSelectedImage>[
        VideoMakerSelectedImage(
          bytes: Uint8List(5 * 1024 * 1024 + 1),
          name: 'trop-lourde.png',
          mimeType: 'image/png',
        ),
      ],
      expected: find.text('Aucune vidéo générée'),
    );

    await tester.tap(find.text('Choisir plusieurs images'));
    await pumpUntil(
      tester,
      () => find
          .text('trop-lourde.png doit être valide et peser moins de 5 Mo.')
          .evaluate()
          .isNotEmpty,
    );

    expect(
      find.text('trop-lourde.png doit être valide et peser moins de 5 Mo.'),
      findsOneWidget,
    );
  });
}
