import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _Wave4MultiFactorPlatform extends MultiFactorPlatform {
  _Wave4MultiFactorPlatform(super.auth);
}

class _Wave4TokenResult extends IdTokenResult {
  _Wave4TokenResult()
    : super(
        InternalIdTokenResult(
          token: 'messaging-wave-4-token',
          claims: const <String?, Object?>{'admin': true},
          authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
          signInProvider: 'password',
        ),
      );
}

class _Wave4UserPlatform extends UserPlatform {
  _Wave4UserPlatform(FirebaseAuthPlatform auth)
    : super(
        auth,
        _Wave4MultiFactorPlatform(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'thread-user',
            email: 'thread-user@ilipresto.fr',
            displayName: 'Utilisateur conversation',
            isAnonymous: false,
            isEmailVerified: true,
            creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            lastSignInTimestamp: DateTime(2026, 7, 23).millisecondsSinceEpoch,
          ),
          providerData: const <Map<String, dynamic>?>[
            <String, dynamic>{
              'providerId': 'password',
              'uid': 'thread-user',
              'email': 'thread-user@ilipresto.fr',
              'displayName': 'Utilisateur conversation',
              'phoneNumber': null,
              'photoURL': null,
              'isAnonymous': false,
              'isEmailVerified': true,
            },
          ],
        ),
      );

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getIdToken(bool forceRefresh) async =>
      'messaging-wave-4-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async =>
      _Wave4TokenResult();
}

class _Wave4AuthPlatform extends FirebaseAuthPlatform {
  _Wave4AuthPlatform() : super(appInstance: null);

  UserPlatform? user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 120,
}) async {
  for (var frame = 0; frame < maxFrames; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Le contenu attendu ne s’est pas affiché : $finder');
}

Future<dynamic> _pumpThread(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    const MaterialApp(
      home: ConversationThreadPage(
        conversationId: 'conversation-wave-4',
        offerTitle: 'Peinture salon',
        currentUserId: 'thread-user',
      ),
    ),
  );
  await _pumpUntil(tester, find.byType(TextField));
  return tester.state(find.byType(ConversationThreadPage));
}

Future<void> _disposeThread(WidgetTester tester) async {
  const preparing = 'Preparation securisee de la messagerie…';
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text(preparing).evaluate().isEmpty) break;
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Wave4AuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _Wave4AuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user = _Wave4UserPlatform(authPlatform);
  });

  tearDown(() {
    authPlatform.user = null;
  });

  testWidgets('couvre la barre emoji et les feuilles de pièces jointes', (
    tester,
  ) async {
    debugPrint('WAVE4 bootstrap-start');
    final dynamic state = await _pumpThread(tester);
    debugPrint('WAVE4 bootstrap-ready');

    state.quickEmojisState = <String>['🔥', '👍', '😊', '🙏', '👌', '💬'];
    state.showEmojiStripState = true;
    state.conversationBlocked = false;
    expect(state.buildEmojiStrip(), isA<Padding>());
    state.conversationBlocked = true;
    expect(state.buildEmojiStrip(), isA<SizedBox>());
    state.conversationBlocked = false;
    debugPrint('WAVE4 emoji-done');

    final Future<void> gateFuture = state.showAttachmentSubscriptionGate(
      const ConversationAttachmentGateDecision(
        title: 'Fichiers réservés à ilipresto+',
        message: 'Passez à ilipresto+ pour envoyer ce document.',
        source: 'messages_document_gate_test',
        stripeEnabled: false,
      ),
    );
    await _pumpUntil(tester, find.text('Fichiers réservés à ilipresto+'));
    expect(
      find.text('Passez à ilipresto+ pour envoyer ce document.'),
      findsOneWidget,
    );
    expect(find.text('Découvrir ilipresto+'), findsOneWidget);
    final laterButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Plus tard'),
    );
    laterButton.onPressed!.call();
    await tester.pump(const Duration(milliseconds: 500));
    await gateFuture;
    debugPrint('WAVE4 subscription-gate-done');

    const document = MessageAttachment(
      type: 'document',
      name: 'devis.pdf',
      url: 'https://cdn.example/devis.pdf',
      storagePath: 'messages/devis.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1200,
    );

    final Future<void> actionsFuture = state.showAttachmentActionsSheet(
      document,
    );
    await _pumpUntil(tester, find.text('Pièce jointe'));
    expect(find.text('devis.pdf'), findsOneWidget);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
    Navigator.of(tester.element(find.text('Pièce jointe'))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    await actionsFuture;
    debugPrint('WAVE4 attachment-sheet-done');

    await state.openAttachment(
      const MessageAttachment(
        type: 'image',
        name: 'photo.webp',
        url: '',
        storagePath: 'messages/photo.webp',
        mimeType: 'image/webp',
        sizeBytes: 200,
      ),
    );
    debugPrint('WAVE4 image-branch-done');

    await _disposeThread(tester);
    debugPrint('WAVE4 dispose-done');
  });
}
