import 'dart:convert';
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
    VideoMakerGenerator? generateVideo,
    VideoMakerImagePicker? pickImage,
    VideoMakerVideoOpener? openVideo,
    VideoMakerVideoSharer? shareVideo,
  }) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminVideoMakerPage(
          loadVideos: loadVideos,
          generateVideo: generateVideo,
          pickImage: pickImage,
          openVideo: openVideo,
          shareVideo: shareVideo,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sélectionne une image et transmet le payload VEO complet',
      (tester) async {
    var loadCalls = 0;
    Map<String, Object?>? generatedParameters;
    final imageBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    await pumpPage(
      tester,
      loadVideos: () async {
        loadCalls += 1;
        return const <GeneratedVideo>[];
      },
      pickImage: () async => VideoMakerSelectedImage(
        bytes: imageBytes,
        name: 'source.png',
        mimeType: 'image/png',
      ),
      generateVideo: (parameters) async {
        generatedParameters = Map<String, Object?>.from(parameters);
      },
    );

    expect(loadCalls, 1);
    await tester.tap(find.text('Ajouter une image de départ (facultatif)'));
    await tester.pumpAndSettle();
    expect(find.text('source.png'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'api-key-test');
    await tester.enterText(fields.at(1), 'Une scène tropicale en mouvement');
    await tester.tap(find.text('16:9 Paysage'));
    await tester.pump();

    await tester.tap(find.text('Générer'));
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(generatedParameters, isNotNull);
    expect(generatedParameters?['prompt'], 'Une scène tropicale en mouvement');
    expect(generatedParameters?['model'], 'veo-3.1-generate-preview');
    expect(generatedParameters?['aspectRatio'], '16:9');
    expect(generatedParameters?['durationSeconds'], '8');
    expect(generatedParameters?['resolution'], '720p');
    expect(generatedParameters?['apiKey'], 'api-key-test');
    expect(generatedParameters?['imageBase64'], base64Encode(imageBytes));
    expect(generatedParameters?['imageMimeType'], 'image/png');
    expect(
      find.text('Vidéo VEO générée et ajoutée à la bibliothèque.'),
      findsOneWidget,
    );

    final apiField = tester.widget<TextField>(fields.at(0));
    expect(apiField.controller?.text, isEmpty);
  });

  testWidgets('refuse un prompt vide puis un prompt supérieur à 4000 caractères',
      (tester) async {
    var generateCalls = 0;
    await pumpPage(
      tester,
      loadVideos: () async => const <GeneratedVideo>[],
      generateVideo: (_) async {
        generateCalls += 1;
      },
    );

    await tester.tap(find.text('Générer'));
    await tester.pump();
    expect(find.text('Ajoutez un prompt avant de générer.'), findsOneWidget);
    expect(generateCalls, 0);

    await tester.pumpAndSettle();
    final promptField = tester.widget<TextField>(find.byType(TextField).at(1));
    promptField.controller!.text = List<String>.filled(4001, 'x').join();
    await tester.pump();
    await tester.tap(find.text('Générer'));
    await tester.pump();

    expect(promptField.controller?.text.length, 4001);
    expect(generateCalls, 0);
  });

  testWidgets('gère URL absente, ouverture impossible, partage fallback et refresh',
      (tester) async {
    var loadCalls = 0;
    Uri? openedUri;
    GeneratedVideo? sharedVideo;
    Rect? sharedOrigin;
    final videos = <GeneratedVideo>[
      const GeneratedVideo(
        id: 'without-url',
        prompt: 'Vidéo sans URL',
        status: 'ready',
        model: 'veo-3.1-generate-preview',
        aspectRatio: '9:16',
        publicUrl: '',
        createdAt: null,
        errorMessage: null,
      ),
      const GeneratedVideo(
        id: 'ready-video',
        prompt: 'Vidéo prête',
        status: 'ready',
        model: 'veo-3.1-generate-preview',
        aspectRatio: '16:9',
        publicUrl: 'https://cdn.test/video.mp4',
        createdAt: null,
        errorMessage: null,
      ),
    ];

    await pumpPage(
      tester,
      loadVideos: () async {
        loadCalls += 1;
        return videos;
      },
      openVideo: (uri) async {
        openedUri = uri;
        return false;
      },
      shareVideo: (video, origin) async {
        sharedVideo = video;
        sharedOrigin = origin;
        return false;
      },
    );

    expect(loadCalls, 1);
    final shareButtons = find.text('Partager');
    final downloadButtons = find.text('Télécharger');
    expect(shareButtons, findsNWidgets(2));
    expect(downloadButtons, findsNWidgets(2));

    await tester.ensureVisible(shareButtons.at(0));
    await tester.tap(shareButtons.at(0));
    await tester.pump();
    expect(
      find.text('La vidéo ne possède pas encore de lien partageable.'),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(downloadButtons.at(1));
    await tester.tap(downloadButtons.at(1));
    await tester.pump();
    expect(openedUri, Uri.parse('https://cdn.test/video.mp4'));

    await tester.pumpAndSettle();
    await tester.ensureVisible(shareButtons.at(1));
    await tester.tap(shareButtons.at(1));
    await tester.pump();
    expect(sharedVideo?.id, 'ready-video');
    expect(sharedOrigin, isNotNull);

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();
    expect(loadCalls, 2);
  });
}
