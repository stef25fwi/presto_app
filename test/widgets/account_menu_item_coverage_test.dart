import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/account_menu_item.dart';

void main() {
  testWidgets('affiche le contenu par défaut et déclenche le callback',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountMenuItem(
            icon: Icons.person,
            label: 'Mon profil',
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await tester.tap(find.text('Mon profil'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('utilise le trailing personnalisé sans afficher le chevron',
      (tester) async {
    const trailingKey = Key('custom-trailing');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountMenuItem(
            icon: Icons.security,
            label: 'Sécurité',
            onTap: () {},
            trailing: const SizedBox(
              key: trailingKey,
              width: 20,
              height: 20,
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(trailingKey), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });
}
