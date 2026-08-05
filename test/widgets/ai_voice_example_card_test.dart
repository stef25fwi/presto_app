import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';
import 'package:presto_app/widgets/ai_voice_example_card.dart';

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

  testWidgets('expose le guide complet aux technologies d assistance', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 360, child: AiVoiceExampleCard()),
        ),
      ),
    );

    expect(find.byIcon(Icons.record_voice_over_rounded), findsOneWidget);
    final node = tester.getSemantics(find.byType(AiVoiceExampleCard));
    expect(
      node.label,
      contains(
        'Je cherche un jardinier pour tailler une haie et nettoyer mon jardin',
      ),
    );
    expect(node.label, contains('dans le secteur de votre commune'));
  });

  testWidgets('conserve sa présentation dans une largeur mobile étroite', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 280, child: AiVoiceExampleCard()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final containers = find.descendant(
      of: find.byType(AiVoiceExampleCard),
      matching: find.byType(Container),
    );
    final card = tester.widget<Container>(containers.first);
    final decoration = card.decoration! as BoxDecoration;

    expect(card.padding, const EdgeInsets.fromLTRB(16, 14, 16, 16));
    expect(decoration.borderRadius, BorderRadius.circular(18));
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
  });
}
