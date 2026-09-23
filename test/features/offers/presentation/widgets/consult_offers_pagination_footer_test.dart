import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/consult_offers_pagination_footer.dart';

void main() {
  Future<void> pumpFooter(WidgetTester tester, {
    bool hasMore = true,
    bool loading = false,
    bool failed = false,
    VoidCallback? onLoad,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: ListView(children: [ConsultOffersPaginationFooter(
          hasMore: hasMore, loading: loading, failed: failed,
          onLoad: onLoad ?? () {},
        )]),
      ),
    )));
  }

  testWidgets('continue même sans carte affichée, sur écran étroit', (tester) async {
    var requests = 0;
    await pumpFooter(tester, onLoad: () => requests++);
    expect(find.text('D’autres annonces restent à parcourir.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consult-load-more')));
    expect(requests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('désactive le bouton pendant une requête', (tester) async {
    var requests = 0;
    await pumpFooter(tester, loading: true, onLoad: () => requests++);
    expect(find.text('Chargement…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consult-load-more')));
    expect(requests, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('propose une nouvelle tentative après un échec', (tester) async {
    var requests = 0;
    await pumpFooter(tester, failed: true, onLoad: () => requests++);
    expect(find.text('La suite des annonces n’a pas pu être chargée.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(requests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('masque la commande quand les pages sont épuisées', (tester) async {
    await pumpFooter(tester, hasMore: false);
    expect(find.byKey(const ValueKey('consult-load-more')), findsNothing);
  });
}
