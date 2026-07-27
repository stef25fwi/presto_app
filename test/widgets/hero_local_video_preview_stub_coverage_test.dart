import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/hero_local_video_preview_stub.dart';

void main() {
  testWidgets('renders the local preview fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HeroLocalVideoPreview(
          bytes: Uint8List.fromList(<int>[1]),
          contentType: 'video/mp4',
        ),
      ),
    );

    expect(find.byType(HeroLocalVideoPreview), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
  });
}
