import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversations_list_page.dart';
import 'package:presto_app/pages/messages/messages_page_v2.dart';

class _MessagesSignedOutPlatform extends FirebaseAuthPlatform {
  _MessagesSignedOutPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _MessagesSignedOutPlatform();
  });

  testWidgets('MessagesPageV2 transmet les paramètres à la liste', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MessagesPageV2(
          initialConversationId: 'conversation-42',
          initialDraftText: 'Bonjour',
        ),
      ),
    );
    await tester.pump();

    final page = tester.widget<ConversationsListPage>(
      find.byType(ConversationsListPage),
    );
    expect(page.initialConversationId, 'conversation-42');
    expect(page.initialDraftText, 'Bonjour');
    expect(page.appBarTitle, 'Mes messages');
    expect(find.text('Mes messages'), findsOneWidget);
  });
}
