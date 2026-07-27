import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presto_app/widgets/photo_selector_tile.dart';

void main() {
  testWidgets('affiche le fallback pour des bytes image invalides et relaie les actions',
      (tester) async {
    var taps = 0;
    var longPresses = 0;
    var removals = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 140,
              child: PhotoSelectorTile(
                label: 'Photo principale',
                file: XFile('photo-invalide.jpg'),
                bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
                onTap: () => taps += 1,
                onLongPress: () => longPresses += 1,
                onRemove: () => removals += 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image), findsOneWidget);
    expect(find.text('Photo principale'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.text('Photo principale'));
    await tester.longPress(find.text('Photo principale'));
    await tester.tap(find.byIcon(Icons.close_rounded));

    expect(taps, 1);
    expect(longPresses, 1);
    expect(removals, 1);
  });
}
