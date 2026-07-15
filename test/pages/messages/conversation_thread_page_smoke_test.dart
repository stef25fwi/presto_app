import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('le fil expose son contexte public et le brouillon initial', () {
    const page = ConversationThreadPage(
      key: ValueKey<String>('thread'),
      conversationId: 'conversation-1',
      offerTitle: 'Mission jardinage',
      currentUserId: 'user-1',
      initialDraftText: 'Bonjour, je suis disponible.',
    );

    expect(page.key, const ValueKey<String>('thread'));
    expect(page.conversationId, 'conversation-1');
    expect(page.offerTitle, 'Mission jardinage');
    expect(page.currentUserId, 'user-1');
    expect(page.initialDraftText, 'Bonjour, je suis disponible.');
    expect(page.createState(), isA<State<ConversationThreadPage>>());
  });

  test('le thème public du fil conserve les couleurs ilipresto', () {
    expect(kPrestoOrange, const Color(0xFFFF6600));
    expect(kPrestoBlue, const Color(0xFF1A73E8));
    expect(kThreadMineColor, const Color(0xFFD9FDD3));
    expect(kThreadOtherColor, Colors.white);
    expect(kThreadBackground, const Color(0xFFFFFEFE));
    expect(kWhatsappGreen, const Color(0xFF25D366));
  });

  test('la barre système du fil reste lisible sur le bandeau orange', () {
    expect(kConversationThreadStatusBarStyle.statusBarColor, kPrestoOrange);
    expect(
      kConversationThreadStatusBarStyle.statusBarIconBrightness,
      Brightness.light,
    );
    expect(
      kConversationThreadStatusBarStyle.statusBarBrightness,
      Brightness.dark,
    );
    expect(kConversationThreadStatusBarStyle, isA<SystemUiOverlayStyle>());
  });
}
