import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';

Widget _app({
  required AiPublishState state,
  bool isAudioAnalyzing = false,
  bool showAdminDiagnostics = false,
  bool highlightVocalCard = false,
  bool dimVocalCard = false,
  required VoidCallback onStart,
  required VoidCallback onStop,
  required VoidCallback onVocal,
  required VoidCallback onText,
  required VoidCallback onDiagnostic,
  required VoidCallback onClear,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AiPublishControl(
          key: const ValueKey('ai-control'),
          state: state,
          micAnchorLink: LayerLink(),
          isAudioAnalyzing: isAudioAnalyzing,
          showAdminDiagnostics: showAdminDiagnostics,
          highlightVocalCard: highlightVocalCard,
          dimVocalCard: dimVocalCard,
          onStartRecording: onStart,
          onStopRecording: onStop,
          onSelectVocal: onVocal,
          onSelectText: onText,
          onDiagnostic: onDiagnostic,
          onClear: onClear,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sélectionne texte puis revient au vocal quand l’enregistrement démarre',
      (tester) async {
    var starts = 0;
    var stops = 0;
    var vocalSelections = 0;
    var textSelections = 0;

    Widget build(AiPublishState state) => _app(
          state: state,
          onStart: () => starts += 1,
          onStop: () => stops += 1,
          onVocal: () => vocalSelections += 1,
          onText: () => textSelections += 1,
          onDiagnostic: () {},
          onClear: () {},
        );

    await tester.pumpWidget(build(AiPublishState.ready));
    expect(find.text('Appuyez pour parler'), findsOneWidget);

    await tester.tap(find.text('Texte + IA'));
    await tester.pump();
    expect(textSelections, 1);
    expect(find.text('Appuyez pour parler'), findsNothing);

    await tester.tap(find.text('IA vocale'));
    await tester.pump();
    expect(vocalSelections, 1);
    expect(find.text('Appuyez pour parler'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic_rounded).last);
    expect(starts, 1);

    await tester.tap(find.text('Texte + IA'));
    await tester.pump();
    expect(find.text('Appuyez pour parler'), findsNothing);

    await tester.pumpWidget(build(AiPublishState.recording));
    await tester.pump();
    expect(find.text('Appuyez pour arrêter'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop_rounded));
    expect(stops, 1);
  });

  testWidgets('affiche analyse, diagnostics admin et exécute les actions',
      (tester) async {
    var diagnostics = 0;
    var clears = 0;
    var starts = 0;

    await tester.pumpWidget(
      _app(
        state: AiPublishState.analyzing,
        isAudioAnalyzing: true,
        showAdminDiagnostics: true,
        highlightVocalCard: true,
        onStart: () => starts += 1,
        onStop: () {},
        onVocal: () {},
        onText: () {},
        onDiagnostic: () => diagnostics += 1,
        onClear: () => clears += 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Analyse en cours…'), findsOneWidget);
    expect(find.text('Diagnostic IA'), findsOneWidget);
    expect(find.text('Effacer'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic_rounded).last);
    expect(starts, 0);

    await tester.tap(find.text('Diagnostic IA'));
    await tester.tap(find.text('Effacer'));
    expect(diagnostics, 1);
    expect(clears, 1);
  });

  testWidgets('désactive la carte vocale estompée', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      _app(
        state: AiPublishState.ready,
        dimVocalCard: true,
        onStart: () => starts += 1,
        onStop: () {},
        onVocal: () {},
        onText: () {},
        onDiagnostic: () {},
        onClear: () {},
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_rounded).last, warnIfMissed: false);
    expect(starts, 0);
  });
}
