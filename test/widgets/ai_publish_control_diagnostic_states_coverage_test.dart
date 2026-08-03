import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('affiche les diagnostics micro recording puis analyzing',
      (tester) async {
    var state = AiPublishState.recording;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return AiPublishControl(
                  state: state,
                  micAnchorLink: LayerLink(),
                  showAdminDiagnostics: true,
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Mode serveur : Whisper'), findsOneWidget);
    expect(find.text('État : Écoute micro'), findsOneWidget);

    setHostState(() => state = AiPublishState.analyzing);
    await tester.pumpAndSettle();

    expect(find.text('ANALYSE'), findsOneWidget);
    expect(find.text('État : Analyse en cours'), findsOneWidget);
  });
}
