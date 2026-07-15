import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/publish_offer_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .physicalSize = const Size(1200, 1800);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetDevicePixelRatio();
  });

  test('formate l heure du diagnostic avec zéros et millisecondes', () {
    expect(
      formatPublishAiTraceTime(DateTime(2026, 7, 15, 3, 4, 5, 6)),
      '03:04:05.006',
    );
  });

  test('associe une icône et une couleur à chaque niveau', () {
    expect(
      iconForPublishAiTraceLevel(PublishAiTraceLevel.info),
      Icons.radio_button_checked_rounded,
    );
    expect(
      iconForPublishAiTraceLevel(PublishAiTraceLevel.success),
      Icons.check_circle_rounded,
    );
    expect(
      iconForPublishAiTraceLevel(PublishAiTraceLevel.warning),
      Icons.warning_amber_rounded,
    );
    expect(
      iconForPublishAiTraceLevel(PublishAiTraceLevel.error),
      Icons.error_rounded,
    );

    expect(colorForPublishAiTraceLevel(PublishAiTraceLevel.info), isA<Color>());
    expect(colorForPublishAiTraceLevel(PublishAiTraceLevel.success), const Color(0xFF2E7D32));
    expect(colorForPublishAiTraceLevel(PublishAiTraceLevel.warning), const Color(0xFFF9A825));
    expect(colorForPublishAiTraceLevel(PublishAiTraceLevel.error), const Color(0xFFC62828));
  });

  testWidgets('la bannière vide ne rend aucun message', (tester) async {
    await tester.pumpWidget(
      app(const PublishValidationBanner(missingFields: <String>[])),
    );

    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining('Complète les champs'), findsNothing);
  });

  testWidgets('la bannière liste les champs manquants', (tester) async {
    await tester.pumpWidget(
      app(
        const PublishValidationBanner(
          missingFields: <String>['titre', 'ville', 'budget'],
        ),
      ),
    );

    expect(
      find.text(
        'Complète les champs mis en évidence : titre, ville, budget.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('le dialogue vide affiche son état et désactive Effacer', (
    tester,
  ) async {
    var clearCalls = 0;
    await tester.pumpWidget(
      app(
        PublishAiTraceDiagnosticDialog(
          entries: const <PublishAiTraceEntry>[],
          runtimeState: 'idle',
          latestTranscript: '   ',
          onClear: () => clearCalls += 1,
        ),
      ),
    );

    expect(find.text('Diagnostic micro IA'), findsOneWidget);
    expect(find.text('Etat: idle'), findsOneWidget);
    expect(find.text('Entrees: 0'), findsOneWidget);
    expect(find.text('Aucun diagnostic pour le moment.'), findsOneWidget);
    expect(find.textContaining('Dernière transcription'), findsNothing);

    await tester.tap(find.text('Effacer'));
    await tester.pump();
    expect(clearCalls, 0);
  });

  testWidgets('le dialogue rend toutes les entrées et efface la liste', (
    tester,
  ) async {
    var clearCalls = 0;
    final entries = <PublishAiTraceEntry>[
      PublishAiTraceEntry(
        timestamp: DateTime(2026, 7, 15, 9, 10, 11, 12),
        level: PublishAiTraceLevel.info,
        stage: 'préparation',
        detail: 'Initialisation du micro',
      ),
      PublishAiTraceEntry(
        timestamp: DateTime(2026, 7, 15, 9, 10, 12, 13),
        level: PublishAiTraceLevel.success,
        stage: 'transcription',
        detail: 'Texte reçu',
      ),
      PublishAiTraceEntry(
        timestamp: DateTime(2026, 7, 15, 9, 10, 13, 14),
        level: PublishAiTraceLevel.warning,
        stage: 'réseau',
        detail: 'Connexion lente',
      ),
      PublishAiTraceEntry(
        timestamp: DateTime(2026, 7, 15, 9, 10, 14, 15),
        level: PublishAiTraceLevel.error,
        stage: 'publication',
        detail: 'Échec du brouillon',
      ),
    ];

    await tester.pumpWidget(
      app(
        PublishAiTraceDiagnosticDialog(
          entries: entries,
          runtimeState: 'error',
          latestTranscript: '  Je recherche un jardinier  ',
          onClear: () => clearCalls += 1,
        ),
      ),
    );

    expect(find.text('Etat: error'), findsOneWidget);
    expect(find.text('Entrees: 4'), findsOneWidget);
    expect(
      find.text('Dernière transcription: Je recherche un jardinier'),
      findsOneWidget,
    );
    expect(find.textContaining('09:10:11.012'), findsOneWidget);
    expect(find.text('Initialisation du micro'), findsOneWidget);
    expect(find.text('Texte reçu'), findsOneWidget);
    expect(find.text('Connexion lente'), findsOneWidget);
    expect(find.text('Échec du brouillon'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);

    await tester.tap(find.text('Effacer'));
    await tester.pump();
    expect(clearCalls, 1);
  });
}
