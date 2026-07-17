import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_models.dart';
import 'package:presto_app/pages/admin_videomaker_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    Future<XFile?> Function() picker,
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

  Future<void> showNotice(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('valide les images invalides et les erreurs de sélection',
      (tester) async {
    var mode = 0;
    await pumpPage(tester, () async {
      mode++;
      if (mode == 1) {
        return XFile.fromData(Uint8List(0), name: 'vide.png');
      }
      if (mode == 2) {
        return XFile.fromData(
          Uint8List.fromList(<int>[1]),
          name: 'animation.gif',
          mimeType: 'image/gif',
        );
      }
      throw StateError('sélection indisponible');
    });
    final pick = find.text('Ajouter une image de départ (facultatif)');

    await tester.tap(pick);
    await showNotice(tester);
    expect(
      find.text('L’image doit être valide et peser moins de 5 Mo.'),
      findsOneWidget,
    );

    await tester.tap(pick);
    await showNotice(tester);
    expect(
      find.text('Utilisez une image JPG, PNG, WEBP, HEIC ou HEIF.'),
      findsOneWidget,
    );

    await tester.tap(pick);
    await showNotice(tester);
    expect(find.text('Impossible de sélectionner cette image.'), findsOneWidget);
  });
}
