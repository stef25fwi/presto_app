import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/admin_web_debug_panel.dart';

void main() {
  testWidgets('preserves the wrapped child outside web', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminWebDebugPanel(
          child: Scaffold(
            body: Text('contenu métier'),
          ),
        ),
      ),
    );

    expect(find.text('contenu métier'), findsOneWidget);
    expect(find.byTooltip('Ouvrir le diagnostic admin'), findsNothing);
  });
}
