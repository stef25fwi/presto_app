import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account/mes_avis_page.dart';

void main() {
  testWidgets('affiche la page Mes avis pour un utilisateur déconnecté',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MesAvisPage(uidOverride: '')),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Mes avis'), findsOneWidget);
    expect(find.text('Non connecté'), findsOneWidget);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isTrue);
    expect(appBar.elevation, 0);
    expect(appBar.foregroundColor, Colors.white);
  });
}
