import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_center_page.dart';
import 'package:presto_app/pages/admin_messaging_moderation_page.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart'
    as thread;
import 'package:presto_app/pages/messages/conversations_list_page.dart'
    as conversations;

void main() {
  test('décrit les requêtes de conversations', () {
    final adminShape = conversations.ConversationsQueryContract.shape(
      isAdminMode: true,
      userId: 'admin-1',
    );
    expect(adminShape['collection'], 'conversations');
    expect(adminShape['orderBy'], 'updatedAt');
    expect(adminShape['descending'], isTrue);
    expect(adminShape['limit'], 50);
    expect(adminShape['participantField'], isNull);
    expect(adminShape['participantValue'], isNull);

    final userShape = conversations.ConversationsQueryContract.shape(
      isAdminMode: false,
      userId: 'user-42',
    );
    expect(userShape['collection'], 'conversations');
    expect(userShape['orderBy'], 'updatedAt');
    expect(userShape['descending'], isTrue);
    expect(userShape['participantField'], 'participantIds');
    expect(userShape['participantValue'], 'user-42');
    expect(userShape['limit'], isNull);
  });

  test('chaque section possède un libellé et une icône', () {
    expect(AdminMessagingSection.values, hasLength(10));
    for (final section in AdminMessagingSection.values) {
      expect(section.label, isNotEmpty);
      expect(section.icon, isA<IconData>());
    }
  });

  test('conserve les paramètres publics du fil de conversation', () {
    const page = thread.ConversationThreadPage(
      conversationId: 'conversation-42',
      offerTitle: 'Peinture salon',
      currentUserId: 'user-42',
      initialDraftText: 'Bonjour, votre annonce est-elle disponible ?',
    );

    expect(page.conversationId, 'conversation-42');
    expect(page.offerTitle, 'Peinture salon');
    expect(page.currentUserId, 'user-42');
    expect(
      page.initialDraftText,
      'Bonjour, votre annonce est-elle disponible ?',
    );
    expect(page.createState(), isA<State<thread.ConversationThreadPage>>());
  });

  test('conserve les paramètres publics de la liste de conversations', () {
    const page = conversations.ConversationsListPage(
      initialConversationId: 'conversation-42',
      initialDraftText: 'Message initial',
      appBarTitle: 'Centre de messages',
    );

    expect(page.initialConversationId, 'conversation-42');
    expect(page.initialDraftText, 'Message initial');
    expect(page.appBarTitle, 'Centre de messages');
    expect(page.createState(), isA<State<conversations.ConversationsListPage>>());

    const defaultPage = conversations.ConversationsListPage();
    expect(defaultPage.initialConversationId, isNull);
    expect(defaultPage.initialDraftText, isNull);
    expect(defaultPage.appBarTitle, 'Mes messages');
  });

  test('expose les styles système et la palette des écrans de messagerie', () {
    expect(thread.kPrestoOrange, const Color(0xFFFF6600));
    expect(thread.kPrestoBlue, const Color(0xFF1A73E8));
    expect(thread.kThreadMineColor, const Color(0xFFD9FDD3));
    expect(thread.kThreadOtherColor, Colors.white);
    expect(thread.kConversationThreadStatusBarStyle.statusBarColor,
        thread.kPrestoOrange);
    expect(
      thread.kConversationThreadStatusBarStyle.statusBarIconBrightness,
      Brightness.light,
    );

    expect(conversations.kPrestoOrange, const Color(0xFFFF6600));
    expect(conversations.kPrestoBlue, const Color(0xFF1A73E8));
    expect(conversations.kMessagesPageBackground, const Color(0xFFFFFEFE));
    expect(
      conversations.kMessagesStatusBarStyle.statusBarColor,
      conversations.kPrestoOrange,
    );
    expect(
      conversations.kMessagesStatusBarStyle.statusBarIconBrightness,
      Brightness.light,
    );
  });

  test('crée l’état de la page de modération', () {
    const page = AdminMessagingModerationPage();
    expect(
      page.createState(),
      isA<State<AdminMessagingModerationPage>>(),
    );
  });
}
