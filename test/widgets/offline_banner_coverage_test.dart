import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/offline_banner.dart';

void main() {
  group('OfflineBanner', () {
    testWidgets('reste invisible quand le mode hors ligne est inactif',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OfflineBanner(isVisible: false)),
      );

      expect(find.text('Mode hors ligne'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('affiche le message complet quand il est visible',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OfflineBanner(isVisible: true)),
        ),
      );

      expect(find.text('Mode hors ligne'), findsOneWidget);
      expect(
        find.text(
          'Consultation uniquement • Les actions d\'écriture sont désactivées',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byType(Material), findsWidgets);
    });
  });

  group('OfflineActionGuard', () {
    testWidgets('exécute directement l’action quand la connexion est active',
        (tester) async {
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineActionGuard(
              isOnline: true,
              onAction: () => calls += 1,
              child: const Text('Continuer'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continuer'));
      await tester.pump();

      expect(calls, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('bloque l’action et affiche le dialogue hors ligne',
        (tester) async {
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineActionGuard(
              isOnline: false,
              onAction: () => calls += 1,
              offlineMessage: 'Connexion requise pour publier.',
              child: const Text('Publier'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Publier'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Mode hors ligne'), findsOneWidget);
      expect(find.text('Connexion requise pour publier.'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('utilise le message hors ligne par défaut', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineActionGuard(
              isOnline: false,
              onAction: () {},
              child: const Text('Modifier'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cette action nécessite une connexion Internet.'),
        findsOneWidget,
      );
    });
  });

  group('OfflineBadge', () {
    testWidgets('reste invisible quand l’utilisateur est en ligne',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OfflineBadge(isOnline: true)),
      );

      expect(find.text('Hors ligne'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('affiche le badge quand l’utilisateur est hors ligne',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OfflineBadge(isOnline: false)),
        ),
      );

      expect(find.text('Hors ligne'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });
}
