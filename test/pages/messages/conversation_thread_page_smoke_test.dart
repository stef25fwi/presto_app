import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _SignedOutThreadAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutThreadAuthPlatform() : super(appInstance: null);

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

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutThreadAuthPlatform();
  });

  testWidgets('le fil affiche immédiatement son contexte et son composeur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationThreadPage(
          conversationId: 'conversation-1',
          offerTitle: 'Mission jardinage',
          currentUserId: 'user-1',
          initialDraftText: 'Bonjour, je suis disponible.',
        ),
      ),
    );

    expect(
      find.byType(ConversationThreadPage, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Mission jardinage', skipOffstage: false), findsWidgets);
    expect(
      find.text(
        'Preparation securisee de la messagerie…',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
    expect(find.text('Votre message...', skipOffstage: false), findsOneWidget);
    expect(
      find.byIcon(Icons.attach_file_rounded, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byIcon(Icons.mic_none_rounded, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(PopupMenuButton, skipOffstage: false), findsOneWidget);

    final field = find.byType(TextField, skipOffstage: false);
    await tester.enterText(field, 'Une réponse rapide');
    await tester.pump();

    expect(find.byIcon(Icons.send_rounded, skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 7));
  });
}
