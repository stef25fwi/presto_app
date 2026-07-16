import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_conversation_detail_page.dart';
import 'package:presto_app/admin/messaging/models/admin_conversation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AdminConversationModel conversation({
    bool watchlisted = false,
    String contextId = '',
    Map<String, String> participantNames = const <String, String>{
      'u1': 'Alice',
      'u2': 'Bob',
    },
    List<String> participantIds = const <String>['u1', 'u2'],
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
  }) {
    return AdminConversationModel(
      id: 'conversation-123456',
      shortId: 'conversa',
      contextId: contextId,
      contextTitle: 'Jardinage urgent',
      category: 'Jardinage',
      region: 'Guadeloupe',
      participantIds: participantIds,
      participantNames: participantNames,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt,
      messageCount: 7,
      status: 'reported',
      riskScore: 68,
      reportCount: 2,
      adminWatchlisted: watchlisted,
      hasAttachments: true,
      hasUnread: true,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester,
    AdminConversationModel value,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: AdminConversationDetailPage(conversation: value)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche toutes les métadonnées et désactive l annonce absente',
      (tester) async {
    final activity = DateTime.utc(2026, 7, 16, 12, 30);
    await pumpPage(
      tester,
      conversation(lastMessageAt: activity),
    );

    expect(find.text('Détail conversation'), findsOneWidget);
    expect(find.text('Jardinage urgent'), findsOneWidget);
    expect(find.text('Alice • Bob'), findsOneWidget);
    expect(find.text('ID conversation: conversation-123456'), findsOneWidget);
    expect(find.text('ID annonce/contexte: '), findsOneWidget);
    expect(find.text('Région: Guadeloupe'), findsOneWidget);
    expect(find.text('Messages: 7'), findsOneWidget);
    expect(find.text('Signalements: 2'), findsOneWidget);
    expect(find.text('Dernière activité: $activity'), findsOneWidget);
    expect(find.text('Actions admin'), findsOneWidget);
    expect(find.text('Résumé de conformité'), findsOneWidget);
    expect(find.text('Watchlist'), findsNothing);
    expect(find.text('Ajouter watchlist'), findsOneWidget);

    final linkedOfferButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, "Ouvrir l'annonce liée"),
    );
    expect(linkedOfferButton.onPressed, isNull);
  });

  testWidgets('affiche la watchlist et annule l action sensible sans réseau',
      (tester) async {
    await pumpPage(
      tester,
      conversation(
        watchlisted: true,
        contextId: 'offer-42',
        participantNames: const <String, String>{},
      ),
    );

    expect(find.text('u1 • u2'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('Retirer watchlist'), findsOneWidget);
    expect(find.text('Dernière activité: inconnue'), findsOneWidget);

    final linkedOfferButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, "Ouvrir l'annonce liée"),
    );
    expect(linkedOfferButton.onPressed, isNotNull);

    await tester.tap(find.text('Retirer watchlist'));
    await tester.pumpAndSettle();

    expect(find.text('Retirer de la watchlist'), findsOneWidget);
    expect(
      find.text("Cette action sera journalisée dans l'audit administrateur."),
      findsOneWidget,
    );
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Retirer'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Retirer de la watchlist'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retirer watchlist'), findsOneWidget);
  });
}
