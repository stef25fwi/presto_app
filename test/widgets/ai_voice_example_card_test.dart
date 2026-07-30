import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';

void main() {
  testWidgets('affiche un exemple guidé avant l enregistrement vocal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiPublishControl(
              state: AiPublishState.ready,
              micAnchorLink: LayerLink(),
              onStartRecording: () {},
              onStopRecording: () {},
              onSelectVocal: () {},
              onSelectText: () {},
              onDiagnostic: () {},
              onClear: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Exemple à dire'), findsOneWidget);
    expect(find.textContaining('Je cherche un'), findsOneWidget);
    expect(find.textContaining('jardinier'), findsOneWidget);
    expect(
      find.textContaining('tailler une haie et nettoyer mon jardin'),
      findsOneWidget,
    );
    expect(find.textContaining('dans le secteur de'), findsOneWidget);
    expect(find.text('Appuyez pour parler'), findsOneWidget);
  });
}
