import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_models.dart';
import 'package:presto_app/pages/admin_videomaker_page.dart';

void main() {
  GeneratedVideo video() {
    return GeneratedVideo(
      id: 'video-1',
      prompt: 'Nouvelle vidéo VEO',
      status: 'ready',
      model: 'veo-3.1-generate-preview',
      aspectRatio: '16:9',
      publicUrl: 'https://example.test/video.mp4',
      createdAt: DateTime.utc(2026, 7, 17),
      errorMessage: null,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required Future<List<GeneratedVideo>> Function() loader,
    required Future<void> Function(Map<String, Object?>) generator,
    Future<XFile?> Function()? picker,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminVideoMakerPage(
          loadVideos: loader,
          generateVideo: generator,
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

  testWidgets('sélectionne une image, génère puis recharge la bibliothèque',
      (tester) async {
    var loads = 0;
    final parameters = <Map<String, Object?>>[];
    final directory = await Directory.systemTemp.createTemp('videomaker-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/depart.png');
    await file.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
    final image = XFile(file.path, name: 'depart.png', mimeType: 'image/png');

    await pumpPage(
      tester,
      loader: () async {
        loads++;
        return loads == 1 ? const <GeneratedVideo>[] : <GeneratedVideo>[video()];
      },
      picker: () async => image,
      generator: (value) async => parameters.add(value),
    );

    await tester.tap(find.text('Ajouter une image de départ (facultatif)'));
    await tester.pumpAndSettle();
    expect(find.text('depart.png'), findsOneWidget);
    expect(find.text('4 o'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'temporary-value');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Un portail bleu peint en accéléré',
    );
    await tester.tap(find.text('16:9 Paysage'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Générer'));
    await pumpUntilFound(tester, find.text('Nouvelle vidéo VEO'));

    expect(parameters, hasLength(1));
    expect(parameters.single['prompt'], 'Un portail bleu peint en accéléré');
    expect(parameters.single['aspectRatio'], '16:9');
    expect(parameters.single['apiKey'], 'temporary-value');
    expect(parameters.single['imageMimeType'], 'image/png');
    expect(parameters.single['imageBase64'], 'AQIDBA==');
    expect(loads, 2);
    expect(
      find.text('Vidéo VEO générée et ajoutée à la bibliothèque.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      isEmpty,
    );

    await tester.tap(find.byTooltip('Retirer l’image'));
    await tester.pump();
    expect(find.text('Ajouter une image de départ (facultatif)'), findsOneWidget);
  });

  testWidgets('bloque les doubles générations pendant le traitement',
      (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await pumpPage(
      tester,
      loader: () async => const <GeneratedVideo>[],
      generator: (_) {
        calls++;
        return completer.future;
      },
    );
    await tester.enterText(find.byType(TextField).at(1), 'Prompt en cours');

    await tester.tap(find.widgetWithText(FilledButton, 'Générer'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Génération VEO en cours…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Génération VEO en cours…'),
      ).onPressed,
      isNull,
    );

    completer.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('traduit une erreur Functions', (tester) async {
    await pumpPage(
      tester,
      loader: () async => const <GeneratedVideo>[],
      generator: (_) async {
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'interdit',
        );
      },
    );

    await tester.enterText(find.byType(TextField).at(1), 'Première tentative');
    await tester.tap(find.widgetWithText(FilledButton, 'Générer'));
    await pumpUntilFound(
      tester,
      find.text('Cette fonction est réservée aux administrateurs.'),
    );
  });

  testWidgets('traduit une erreur générique', (tester) async {
    await pumpPage(
      tester,
      loader: () async => const <GeneratedVideo>[],
      generator: (_) async => throw StateError('échec'),
    );

    await tester.enterText(find.byType(TextField).at(1), 'Deuxième tentative');
    await tester.tap(find.widgetWithText(FilledButton, 'Générer'));
    await pumpUntilFound(
      tester,
      find.text('La génération a échoué. Vérifiez la clé API et réessayez.'),
    );
  });
}
