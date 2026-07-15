import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .physicalSize = const Size(1000, 1800);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetDevicePixelRatio();
  });

  testWidgets('le mode vocal prêt démarre puis peut basculer au texte', (
    tester,
  ) async {
    var starts = 0;
    var vocalSelections = 0;
    var textSelections = 0;

    await tester.pumpWidget(
      app(
        AiPublishControl(
          state: AiPublishState.ready,
          micAnchorLink: LayerLink(),
          onStartRecording: () => starts += 1,
          onStopRecording: () {},
          onSelectVocal: () => vocalSelections += 1,
          onSelectText: () => textSelections += 1,
          onDiagnostic: () {},
          onClear: () {},
        ),
      ),
    );

    expect(find.text('Appuyez pour parler'), findsOneWidget);
    expect(find.text("Parlez, l'IA complète l'annonce"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic_rounded).last);
    await tester.pump();
    expect(starts, 1);

    await tester.tap(find.text('Texte + IA'));
    await tester.pump();
    expect(textSelections, 1);
    expect(find.text('Appuyez pour parler'), findsNothing);

    await tester.tap(find.text('IA vocale'));
    await tester.pump();
    expect(vocalSelections, 1);
    expect(find.text('Appuyez pour parler'), findsOneWidget);
  });

  testWidgets('un enregistrement affiche stop et désactive les méthodes', (
    tester,
  ) async {
    var stops = 0;
    var selections = 0;

    await tester.pumpWidget(
      app(
        AiPublishControl(
          state: AiPublishState.recording,
          micAnchorLink: LayerLink(),
          onStartRecording: () {},
          onStopRecording: () => stops += 1,
          onSelectVocal: () => selections += 1,
          onSelectText: () => selections += 1,
          onDiagnostic: () {},
          onClear: () {},
        ),
      ),
    );

    expect(find.text('Appuyez pour arrêter'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    expect(stops, 1);

    await tester.tap(find.text('Texte + IA'));
    await tester.pump();
    expect(selections, 0);
  });

  testWidgets('l analyse bloque le micro et affiche son état', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      app(
        AiPublishControl(
          state: AiPublishState.analyzing,
          micAnchorLink: LayerLink(),
          isAudioAnalyzing: true,
          onStartRecording: () => starts += 1,
          onStopRecording: () {},
          onSelectVocal: () {},
          onSelectText: () {},
          onDiagnostic: () {},
          onClear: () {},
        ),
      ),
    );

    expect(find.text('Analyse en cours…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byIcon(Icons.mic_rounded).last);
    await tester.pump();
    expect(starts, 0);
  });

  testWidgets('le passage ready vers recording revient au mode vocal', (
    tester,
  ) async {
    var state = AiPublishState.ready;
    late StateSetter setHostState;

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return AiPublishControl(
              state: state,
              micAnchorLink: LayerLink(),
              onStartRecording: () {},
              onStopRecording: () {},
              onSelectVocal: () {},
              onSelectText: () {},
              onDiagnostic: () {},
              onClear: () {},
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Texte + IA'));
    await tester.pump();
    expect(find.text('Appuyez pour parler'), findsNothing);

    setHostState(() => state = AiPublishState.recording);
    await tester.pump();
    expect(find.text('Appuyez pour arrêter'), findsOneWidget);
  });

  testWidgets('les diagnostics admin déclenchent les deux actions', (
    tester,
  ) async {
    var diagnostics = 0;
    var clears = 0;

    await tester.pumpWidget(
      app(
        AiPublishControl(
          state: AiPublishState.ready,
          micAnchorLink: LayerLink(),
          highlightVocalCard: true,
          dimVocalCard: true,
          showAdminDiagnostics: true,
          onStartRecording: () {},
          onStopRecording: () {},
          onSelectVocal: () {},
          onSelectText: () {},
          onDiagnostic: () => diagnostics += 1,
          onClear: () => clears += 1,
        ),
      ),
    );

    expect(find.text('Diagnostic IA'), findsOneWidget);
    expect(find.text('Effacer'), findsOneWidget);

    await tester.tap(find.text('Diagnostic IA'));
    await tester.tap(find.text('Effacer'));
    await tester.pump();
    expect(diagnostics, 1);
    expect(clears, 1);
  });

  testWidgets('AiWritingButton expose les états normal et analyse', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      app(
        AiWritingButton(
          isAnalyzing: false,
          onTap: () => taps += 1,
        ),
      ),
    );

    expect(
      find.text("Appuyez pour améliorer votre description avec l'IA"),
      findsOneWidget,
    );
    await tester.tap(find.byType(AiWritingButton));
    await tester.pump();
    expect(taps, 1);

    await tester.pumpWidget(
      app(const AiWritingButton(isAnalyzing: true, onTap: null)),
    );
    expect(find.text('Amélioration en cours…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
