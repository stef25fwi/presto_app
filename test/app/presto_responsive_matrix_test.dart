import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_design_tokens.dart';
import 'package:presto_app/app/presto_states.dart';
import 'package:presto_app/app/theme.dart';
import 'package:presto_app/pages/admin_space_hub_page.dart';

/// Matrice responsive : cinq largeurs de référence croisées avec trois
/// facteurs de texte, jusqu’à 200 %.
///
/// Un débordement de mise en page lève une exception pendant le rendu en mode
/// test. Chaque case de la matrice vérifie donc trois choses : aucune
/// exception, l’action essentielle toujours présente, et une cible tactile
/// toujours atteignable.

typedef ScreenBuilder = Widget Function();

Future<void> _pumpAt(
  WidgetTester tester,
  double width,
  double textScale,
  Widget child,
) async {
  const height = 900.0;
  await tester.binding.setSurfaceSize(Size(width, height));
  // La remise à zéro doit rester dans le contexte du test : la faire depuis un
  // `tearDown` global échoue, la liaison n'étant plus en cours de test.
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildPrestoTheme(),
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: widget!,
      ),
      home: child,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('états partagés sur toute la matrice', () {
    for (final width in PrestoAccessibility.responsiveWidths) {
      for (final scale in PrestoAccessibility.textScales) {
        testWidgets(
          'état vide lisible et actionnable à ${width.toInt()} px et '
          '${(scale * 100).toInt()} %',
          (tester) async {
            await _pumpAt(
              tester,
              width,
              scale,
              Scaffold(
                body: PrestoEmptyState(
                  title: 'Aucune annonce pour le moment',
                  message: 'Publiez votre première annonce pour être visible.',
                  actionLabel: 'Publier une annonce',
                  onAction: () {},
                ),
              ),
            );

            expect(tester.takeException(), isNull);
            expect(find.text('Publier une annonce'), findsOneWidget);
            expect(
              tester.getSize(find.byType(FilledButton)).height,
              greaterThanOrEqualTo(PrestoAccessibility.minTouchTarget),
            );
          },
        );

        testWidgets(
          'état erreur conserve sa reprise à ${width.toInt()} px et '
          '${(scale * 100).toInt()} %',
          (tester) async {
            var retried = false;
            await _pumpAt(
              tester,
              width,
              scale,
              Scaffold(
                body: PrestoErrorState(
                  message: 'La connexion a échoué.',
                  onRetry: () => retried = true,
                ),
              ),
            );

            expect(tester.takeException(), isNull);
            await tester.tap(find.byType(FilledButton));
            await tester.pump();
            expect(
              retried,
              isTrue,
              reason: 'La reprise doit rester atteignable à toute échelle.',
            );
          },
        );
      }
    }
  });

  group('écran réel sur toute la matrice', () {
    for (final width in PrestoAccessibility.responsiveWidths) {
      for (final scale in PrestoAccessibility.textScales) {
        testWidgets(
          'le hub d’administration tient à ${width.toInt()} px et '
          '${(scale * 100).toInt()} %',
          (tester) async {
            await _pumpAt(tester, width, scale, const AdminSpaceHubPage());

            expect(tester.takeException(), isNull);
            expect(find.text('Acquisition & trafic'), findsOneWidget);
          },
        );
      }
    }
  });

  test('la matrice couvre bien les bornes annoncées', () {
    // Les bornes documentées et les bornes testées doivent rester la même
    // liste : une preuve responsive qui ne cite pas les largeurs réellement
    // exercées ne prouve rien.
    expect(PrestoAccessibility.responsiveWidths.first, 320);
    expect(PrestoAccessibility.responsiveWidths.last, 1440);
    expect(PrestoAccessibility.textScales.last, greaterThanOrEqualTo(2.0));
    for (final width in PrestoAccessibility.responsiveWidths) {
      expect(PrestoBreakpoints.classify(width), isA<PrestoWindowClass>());
    }
  });
}
