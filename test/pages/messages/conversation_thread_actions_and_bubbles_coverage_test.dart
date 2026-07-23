import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _ActionsMultiFactorPlatform extends MultiFactorPlatform {
  _ActionsMultiFactorPlatform(super.auth);
}

class _ActionsTokenResult extends IdTokenResult {
  _ActionsTokenResult()
    : super(
        InternalIdTokenResult(
          token: 'messaging-actions-token',
          claims: const <String?, Object?>{'admin': true},
          authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
          signInProvider: 'password',
        ),
      );
}

class _ActionsUserPlatform extends UserPlatform {
  _ActionsUserPlatform(FirebaseAuthPlatform auth)
    : super(
        auth,
        _ActionsMultiFactorPlatform(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'thread-user',
            email: 'thread-user@ilipresto.fr',
            displayName: 'Utilisateur conversation',
            isAnonymous: false,
            isEmailVerified: true,
            creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            lastSignInTimestamp: DateTime(2026, 7, 22).millisecondsSinceEpoch,
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
      'messaging-actions-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async =>
      _ActionsTokenResult();
}

class _ActionsAuthPlatform extends FirebaseAuthPlatform {
  _ActionsAuthPlatform() : super(appInstance: null);

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

Future<void> _pumpUntilReady(WidgetTester tester) async {
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(TextField).evaluate().isNotEmpty) return;
  }
  fail('Le fil de discussion ne s’est pas affiché.');
}

Future<void> _waitForBootstrap(WidgetTester tester) async {
  const preparing = 'Preparation securisee de la messagerie…';
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text(preparing).evaluate().isEmpty) return;
  }
  fail('Le bootstrap messagerie ne s’est pas stabilisé.');
}

Future<dynamic> _pumpThread(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    const MaterialApp(
      home: ConversationThreadPage(
        conversationId: 'conversation-actions-wave',
        offerTitle: 'Peinture salon',
        currentUserId: 'thread-user',
      ),
    ),
  );
  await _pumpUntilReady(tester);
  return tester.state(find.byType(ConversationThreadPage));
}

Future<void> _disposeThread(WidgetTester tester) async {
  await _waitForBootstrap(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ActionsAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _ActionsAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user = _ActionsUserPlatform(authPlatform);
  });

  tearDown(() {
    authPlatform.user = null;
  });

  testWidgets('couvre les messages optimistes et les états d accès', (
    tester,
  ) async {
    final dynamic state = await _pumpThread(tester);

    expect(state.isNearLatestMessage(), isTrue);
    state.showNewMessagesButton = true;
    state.scrollToLatestMessage();
    await tester.pump();

    final sending = OptimisticMessage(
      id: 'local-sending',
      text: 'Message en cours',
      sentAt: DateTime(2026, 7, 22, 10),
      senderName: 'Moi',
      status: OptimisticMessageStatus.sending,
    );
    final second = OptimisticMessage(
      id: 'local-second',
      text: 'Second message',
      sentAt: DateTime(2026, 7, 22, 10, 1),
      senderName: 'Moi',
      status: OptimisticMessageStatus.sending,
    );
    state.setState(() {
      state.optimisticMessages
        ..clear()
        ..addAll(<OptimisticMessage>[sending, second]);
    });
    await tester.pump();

    state.markOptimisticMessageFailed('local-sending');
    await tester.pump();
    expect(
      state.optimisticMessages.first.status,
      OptimisticMessageStatus.failed,
    );
    state.markOptimisticMessageFailed('missing');
    await tester.pump();
    expect(state.optimisticMessages, hasLength(2));

    state.removeOptimisticMessage('local-second');
    await tester.pump();
    expect(state.optimisticMessages, hasLength(1));
    state.removeOptimisticMessage('missing');
    await tester.pump();
    expect(state.optimisticMessages.single.id, 'local-sending');

    state.preparingMessageStream = true;
    final Widget preparingGate = state.buildMessagesAccessGate();
    state.preparingMessageStream = false;
    final Widget unavailableGate = state.buildMessagesAccessGate();

    await _disposeThread(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(child: preparingGate),
              Expanded(child: unavailableGate),
            ],
          ),
        ),
      ),
    );
    expect(
      find.text('Preparation securisee de la messagerie…'),
      findsOneWidget,
    );
    expect(
      find.text(
        'La messagerie est temporairement indisponible. Verifiez App Check, votre connexion puis reessayez.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reessayer'), findsOneWidget);
  });

  testWidgets('rend les pièces jointes et toutes les variantes de bulles', (
    tester,
  ) async {
    final dynamic state = await _pumpThread(tester);
    state.otherParticipantNameState = 'Alice';
    state.otherParticipantPhotoUrl = '';
    state.otherParticipantIdState = 'other-user';

    const document = MessageAttachment(
      type: 'document',
      name: 'devis.pdf',
      url: 'https://cdn/devis.pdf',
      storagePath: 'messages/devis.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1200,
    );
    const image = MessageAttachment(
      type: 'image',
      name: 'Photo',
      url: '',
      thumbnailUrl: '',
      storagePath: 'messages/photo.webp',
      mimeType: 'image/webp',
      sizeBytes: 200,
    );

    var deleteCalls = 0;
    var retryCalls = 0;
    final Widget documentPreview = KeyedSubtree(
      key: const ValueKey<String>('document-preview'),
      child: state.buildAttachmentPreview(
        document,
        canDelete: true,
        onDelete: () => deleteCalls += 1,
      ),
    );
    final Widget deletingPreview = KeyedSubtree(
      key: const ValueKey<String>('deleting-preview'),
      child: state.buildAttachmentPreview(
        document,
        canDelete: true,
        isDeleting: true,
        onDelete: () {},
      ),
    );
    final Widget imagePreview = KeyedSubtree(
      key: const ValueKey<String>('image-preview'),
      child: state.buildAttachmentPreview(image),
    );
    final Widget emptyPreviews = state.buildAttachmentPreviews(
      const <MessageAttachment>[],
    );
    final Widget multiplePreviews = state.buildAttachmentPreviews(
      const <MessageAttachment>[document, document],
    );
    final Widget avatar = state.buildOtherParticipantMessageAvatar();

    final Widget mine = state.buildMessageBubble(
      text: 'Bonjour',
      isMine: true,
      senderName: 'Moi',
      sentAt: DateTime(2026, 7, 22, 10),
      readReceipt: 'Vu',
      statusLabel: 'Envoyé',
      groupedWithOlder: true,
      groupedWithNewer: true,
    );
    final Widget other = state.buildMessageBubble(
      text: 'Réponse',
      isMine: false,
      senderName: 'Alice',
      sentAt: DateTime(2026, 7, 22, 10, 1),
    );
    final Widget deleted = state.buildMessageBubble(
      text: 'Ancien texte',
      isMine: true,
      senderName: 'Moi',
      sentAt: null,
      isDeleted: true,
    );
    final Widget moderated = state.buildMessageBubble(
      text: 'Texte masqué',
      isMine: false,
      senderName: 'Alice',
      sentAt: DateTime(2026, 7, 22, 10, 2),
      isModerated: true,
      moderatedPlaceholder: 'Message en vérification',
    );
    final Widget failed = state.buildMessageBubble(
      text: 'Échec',
      isMine: true,
      senderName: 'Moi',
      sentAt: DateTime(2026, 7, 22, 10, 3),
      failed: true,
      onRetry: () => retryCalls += 1,
    );
    final Widget withDocument = state.buildMessageBubble(
      text: 'Document : devis.pdf',
      isMine: true,
      senderName: 'Moi',
      sentAt: DateTime.now(),
      messageDocId: 'message-document',
      attachments: const <MessageAttachment>[document],
    );

    await _disposeThread(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                documentPreview,
                deletingPreview,
                imagePreview,
                emptyPreviews,
                multiplePreviews,
                avatar,
                mine,
                other,
                deleted,
                moderated,
                failed,
                withDocument,
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.delete_rounded), findsAtLeastNWidgets(1));
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.attach_file_rounded), findsAtLeastNWidgets(3));
    expect(find.text('A'), findsWidgets);
    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Réponse'), findsOneWidget);
    expect(find.text('Message supprimé'), findsOneWidget);
    expect(find.text('Message en vérification'), findsOneWidget);
    expect(find.text('Échec'), findsOneWidget);
    expect(find.text('Document : devis.pdf'), findsOneWidget);
    expect(find.textContaining('Vu'), findsOneWidget);
    expect(find.textContaining('Envoyé'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_rounded).first);
    await tester.pump();
    expect(deleteCalls, 1);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    expect(retryCalls, 1);
  });

  testWidgets('couvre les composants visuels autonomes du fil', (tester) async {
    var actionCalls = 0;
    var cancelCalls = 0;
    var sendCalls = 0;

    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                AttachmentActionTile(
                  icon: Icons.description_outlined,
                  title: 'Ajouter un document',
                  subtitle: 'PDF et fichiers bureautiques',
                  onTap: () => actionCalls += 1,
                ),
                const ConversationBanner(
                  icon: Icons.info_outline,
                  color: Colors.orange,
                  message: 'Information de conversation',
                ),
                const SizedBox(
                  width: 180,
                  height: 120,
                  child: ConversationPatternBackground(),
                ),
                VoiceRecordingSheet(
                  onCancel: () => cancelCalls += 1,
                  onSend: () => sendCalls += 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ajouter un document'), findsOneWidget);
    expect(find.text('PDF et fichiers bureautiques'), findsOneWidget);
    expect(find.text('Information de conversation'), findsOneWidget);
    expect(find.text('Enregistrement en cours…'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);

    await tester.tap(find.text('Ajouter un document'));
    await tester.tap(find.text('Annuler'));
    await tester.tap(find.text('Envoyer'));
    expect(actionCalls, 1);
    expect(cancelCalls, 1);
    expect(sendCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    final painter = ConversationPatternPainter();
    expect(painter.shouldRepaint(ConversationPatternPainter()), isFalse);
  });
}
