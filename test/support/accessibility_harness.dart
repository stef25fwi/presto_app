import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_design_tokens.dart';
import 'package:presto_app/app/theme.dart';

/// Outillage partagé des contrôles d'accessibilité et de responsive.
///
/// Les règles intégrées de Flutter ne valent que si elles sont appliquées à un
/// arbre réellement construit. Ces fonctions rendent cette application
/// uniforme d'un écran à l'autre, pour que la preuve soit comparable.

/// Rend un écran à une largeur et un facteur de texte donnés.
///
/// La remise à zéro de la surface est enregistrée dans le test courant : la
/// faire depuis un `tearDown` global échoue, la liaison n'étant plus en cours
/// de test.
Future<void> pumpAtSize(
  WidgetTester tester,
  Widget screen, {
  double width = 430,
  double height = 900,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildPrestoTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: screen,
    ),
  );
  await settleFrames(tester);
}

/// Stabilise l'arbre sans exiger le repos complet.
///
/// Un écran comportant un indicateur de progression, une animation en boucle
/// ou un flux ouvert n'atteint jamais le repos : `pumpAndSettle` expirerait.
Future<void> settleFrames(WidgetTester tester, {int frames = 3}) async {
  for (var index = 0; index < frames; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Applique les quatre règles d'accessibilité intégrées de Flutter.
///
/// Les libellés ne sont vérifiés que sur demande : un écran encore en
/// chargement peut n'exposer aucune cible tactile à nommer, et exiger la
/// règle produirait une preuve vide plutôt qu'une preuve solide.
Future<void> expectMeetsAccessibilityGuidelines(
  WidgetTester tester, {
  bool checkLabels = true,
}) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  if (checkLabels) {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  }
}

/// Largeurs et facteurs de texte de la matrice officielle.
Iterable<({double width, double scale})> responsiveMatrix() sync* {
  for (final width in PrestoAccessibility.responsiveWidths) {
    for (final scale in PrestoAccessibility.textScales) {
      yield (width: width, scale: scale);
    }
  }
}
