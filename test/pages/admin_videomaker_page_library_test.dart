import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_models.dart';
import 'package:presto_app/pages/admin_videomaker_page.dart';

void main() {
  GeneratedVideo video({
    String id = 'video-1',
    String status = 'ready',
    String? url = 'https://example.test/video.mp4',
    String prompt = 'Une plage tropicale au lever du jour',
    String? error,
  }) {
    return GeneratedVideo(
      id: id,
      prompt: prompt,
      status: status,
      model: 'veo-3.1-generate-preview',
      aspectRatio: '9:16',
      publicUrl: url,
      createdAt: DateTime.utc(2026, 7, 17, 8, 30),
      errorMessage: error,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester,
    Future<List<GeneratedVideo>> Function() loader, {
    Future<void> Function(Map<String, Object?>)? generator,
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
        ),
      ),
    );
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Widget attendu introuvable après traitement asynchrone: $finder');
  }

  Finder refreshButton() => find.widgetWithIcon(IconButton, Icons.refresh_rounded);

  testWidgets('affiche le chargement initial et désactive l’actualisation',
      (tester) async {
    final completer = Completer<List<GeneratedVideo>>();
    await pumpPage(tester, () => completer.future);
    await tester.pump();

    expect(find.text('Videomaker'), findsOneWidget);
    expect(find.text('Créer une vidéo avec VEO'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(tester.widget<IconButton>(refreshButton()).onPressed, isNull);

    completer.complete(const <GeneratedVideo>[]);
    await pumpUntilFound(tester, find.text('Aucune vidéo générée'));
    expect(
      find.text('Votre première création VEO apparaîtra ici.'),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(refreshButton()).onPressed, isNotNull);
  });

  testWidgets('charge les vidéos et affiche leurs trois statuts',
      (tester) async {
    await pumpPage(
      tester,
      () async => <GeneratedVideo>[
        video(),
        video(id: 'video-2', status: 'processing', url: null),
        video(
          id: 'video-3',
          status: 'failed',
          url: null,
          error: 'Quota VEO atteint',
        ),
      ],
    );
    await flush(tester);

    expect(find.text('3'), findsOneWidget);
    expect(find.text('Prête'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Échec'), findsOneWidget);
    expect(find.text('Quota VEO atteint'), findsOneWidget);
    expect(find.text('Télécharger'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
  });

  testWidgets('affiche une erreur puis réussit lors de l’actualisation',
      (tester) async {
    var calls = 0;
    await pumpPage(tester, () async {
      calls++;
      if (calls == 1) throw StateError('indisponible');
      return <GeneratedVideo>[video(prompt: 'Vidéo après actualisation')];
    });
    await pumpUntilFound(
      tester,
      find.text('Impossible de charger la bibliothèque de vidéos.'),
    );

    await tester.tap(refreshButton());
    await pumpUntilFound(tester, find.text('Vidéo après actualisation'));
    expect(calls, 2);
  });

  testWidgets('modifie la visibilité de la clé et le format vidéo',
      (tester) async {
    await pumpPage(tester, () async => const <GeneratedVideo>[]);
    await flush(tester);

    final apiField = find.byType(TextField).at(0);
    expect(tester.widget<TextField>(apiField).obscureText, isTrue);
    await tester.tap(find.byTooltip('Afficher la clé'));
    await tester.pump();
    expect(tester.widget<TextField>(apiField).obscureText, isFalse);

    await tester.tap(find.text('16:9 Paysage'));
    await tester.pump();
    final segmented = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(segmented.selected, <String>{'16:9'});
  });

  testWidgets('refuse une génération sans prompt', (tester) async {
    var generated = false;
    await pumpPage(
      tester,
      () async => const <GeneratedVideo>[],
      generator: (_) async => generated = true,
    );
    await flush(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Générer'));
    await pumpUntilFound(tester, find.text('Ajoutez un prompt avant de générer.'));
    expect(generated, isFalse);
  });
}
