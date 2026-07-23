import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _StateWaveMultiFactorPlatform extends MultiFactorPlatform {
  _StateWaveMultiFactorPlatform(super.auth);
}

class _StateWaveTokenResult extends IdTokenResult {
  _StateWaveTokenResult()
    : super(
        InternalIdTokenResult(
          token: 'messaging-state-token',
          claims: const <String?, Object?>{'admin': true},
          authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
          signInProvider: 'password',
        ),
      );
}

class _StateWaveUserPlatform extends UserPlatform {
  _StateWaveUserPlatform(FirebaseAuthPlatform auth)
    : super(
        auth,
        _StateWaveMultiFactorPlatform(auth),
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
      'messaging-state-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async =>
      _StateWaveTokenResult();
}

class _StateWaveAuthPlatform extends FirebaseAuthPlatform {
  _StateWaveAuthPlatform() : super(appInstance: null);

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
  fail('Le fil de discussion ne s’est pas affiché après 60 secondes simulées.');
}

Future<void> _waitForBootstrap(WidgetTester tester) async {
  const preparing = 'Preparation securisee de la messagerie…';
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text(preparing).evaluate().isEmpty) return;
  }
  fail('Le bootstrap messagerie ne s’est pas stabilisé.');
}

Future<dynamic> _pumpThread(
  WidgetTester tester, {
  String? initialDraftText,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    MaterialApp(
      home: ConversationThreadPage(
        conversationId: 'conversation-state-wave',
        offerTitle: 'Peinture salon',
        currentUserId: 'thread-user',
        initialDraftText: initialDraftText,
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

  late _StateWaveAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _StateWaveAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user = _StateWaveUserPlatform(authPlatform);
  });

  tearDown(() {
    authPlatform.user = null;
  });

  testWidgets('traduit les erreurs du flux et couvre l en-tête du fil', (
    tester,
  ) async {
    final dynamic state = await _pumpThread(tester);

    state.threadParticipants = <String>['thread-user', 'other-user'];
    expect(
      state.messageStreamErrorMessage(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      ),
      'Accès refusé par Firestore malgré votre présence dans les participants. Vérifiez App Check ou les règles de lecture.',
    );
    state.threadParticipants = <String>['other-user'];
    expect(
      state.messageStreamErrorMessage(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      ),
      'Cette conversation n’est pas disponible pour ce compte.',
    );

    final errorCases = <String, String>{
      'unauthenticated': 'Connectez-vous pour lire cette conversation.',
      'not-found': 'Cette conversation n’existe pas encore ou a été supprimée.',
      'failed-precondition':
          'Cette conversation ne peut pas être chargée dans son état actuel.',
      'internal':
          'Les messages sont temporairement indisponibles. Réessayez dans un instant.',
    };
    for (final entry in errorCases.entries) {
      expect(
        state.messageStreamErrorMessage(
          FirebaseFunctionsException(code: entry.key, message: ''),
        ),
        entry.value,
        reason: entry.key,
      );
    }

    state.conversationOfferTitle = '';
    state.otherParticipantNameState = '';
    expect(state.headerOfferTitle, 'Peinture salon');
    expect(state.headerDisplayName, 'Peinture salon');
    expect(state.conversationInitial(), 'P');

    state.conversationOfferTitle = 'Annonce synchronisée';
    state.otherParticipantNameState = ' alice ';
    expect(state.headerOfferTitle, 'Annonce synchronisée');
    expect(state.headerDisplayName, 'alice');
    expect(state.conversationInitial(), 'A');

    state.otherIsTyping = true;
    expect(state.headerSubtitle, 'alice écrit…');
    state.otherIsTyping = false;
    state.otherPresenceStatus = ' ONLINE ';
    state.otherLastSeenAt = null;
    expect(state.headerSubtitle, 'en ligne');
    expect(state.isRecentlySeen(null), isTrue);
    expect(
      state.isRecentlySeen(DateTime.now().subtract(const Duration(minutes: 2))),
      isTrue,
    );
    expect(
      state.isRecentlySeen(
        DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      isFalse,
    );

    state.otherLastSeenAt = DateTime.now().subtract(
      const Duration(minutes: 10),
    );
    expect(state.headerSubtitle, startsWith('vu '));
    state.otherPresenceStatus = '';
    state.otherLastSeenAt = null;
    expect(state.headerSubtitle, 'Annonce synchronisée');

    await _disposeThread(tester);
  });

  testWidgets('calcule les reçus de lecture et applique le brouillon initial', (
    tester,
  ) async {
    final dynamic state = await _pumpThread(
      tester,
      initialDraftText: 'Bonjour depuis la fiche annonce',
    );

    final sentAt = DateTime(2026, 7, 22, 10);
    expect(state.readReceiptLabel(null), isNull);

    state.threadParticipants = <String>['thread-user'];
    state.threadLastReadAt = <String, dynamic>{};
    expect(state.readReceiptLabel(sentAt), isNull);

    state.threadParticipants = <String>['thread-user', 'other-user'];
    state.threadLastReadAt = <String, dynamic>{
      'other-user': sentAt.subtract(const Duration(seconds: 1)),
    };
    expect(state.readReceiptLabel(sentAt), isNull);

    state.threadLastReadAt = <String, dynamic>{'other-user': sentAt};
    expect(state.readReceiptLabel(sentAt), 'Vu');
    state.threadLastReadAt = <String, dynamic>{
      'other-user': sentAt.add(const Duration(minutes: 1)),
    };
    expect(state.readReceiptLabel(sentAt), 'Vu');

    state.didApplyInitialDraft = false;
    state.messageController.clear();
    state.applyInitialDraftIfNeeded(false);
    await tester.pump();
    expect(state.didApplyInitialDraft, isTrue);
    expect(state.messageController.text, 'Bonjour depuis la fiche annonce');
    expect(
      state.messageController.selection.baseOffset,
      'Bonjour depuis la fiche annonce'.length,
    );

    state.didApplyInitialDraft = false;
    state.messageController.clear();
    state.applyInitialDraftIfNeeded(true);
    await tester.pump();
    expect(state.didApplyInitialDraft, isFalse);
    expect(state.messageController.text, isEmpty);

    state.messageController.text = 'Texte déjà saisi';
    state.applyInitialDraftIfNeeded(false);
    await tester.pump();
    expect(state.didApplyInitialDraft, isTrue);
    expect(state.messageController.text, 'Texte déjà saisi');

    await _disposeThread(tester);
  });

  testWidgets('affiche toutes les variantes bloqué et archivé', (tester) async {
    final dynamic state = await _pumpThread(tester);

    void configure({
      required bool blocked,
      bool ownBlock = false,
      bool otherBlock = false,
      bool admin = false,
      bool archived = false,
    }) {
      state.setState(() {
        state.conversationBlocked = blocked;
        state.blockedForCurrentUser = ownBlock;
        state.blockedByAnotherParticipant = otherBlock;
        state.adminViewerState = admin;
        state.archivedForCurrentUser = archived;
      });
    }

    configure(blocked: true, ownBlock: true);
    await tester.pump();
    expect(
      find.text(
        'Vous avez bloque cette conversation. Debloquez-la pour reprendre les echanges.',
      ),
      findsOneWidget,
    );

    configure(blocked: true, otherBlock: true, admin: true);
    await tester.pump();
    expect(
      find.text(
        'Cette conversation a ete bloquee par un participant. Un admin peut la debloquer.',
      ),
      findsOneWidget,
    );

    configure(blocked: true, otherBlock: true);
    await tester.pump();
    expect(
      find.text('Cette conversation a ete bloquee par l autre participant.'),
      findsOneWidget,
    );

    configure(blocked: true);
    await tester.pump();
    expect(
      find.text('Cette conversation est actuellement bloquee.'),
      findsOneWidget,
    );

    configure(blocked: false, archived: true);
    await tester.pump();
    expect(
      find.text(
        'Conversation archivee pour vous. Un nouveau message la restaurera automatiquement.',
      ),
      findsOneWidget,
    );

    configure(blocked: false);
    await tester.pump();
    expect(
      find.text('Cette conversation est actuellement bloquee.'),
      findsNothing,
    );
    expect(
      find.text(
        'Conversation archivee pour vous. Un nouveau message la restaurera automatiquement.',
      ),
      findsNothing,
    );

    await _disposeThread(tester);
  });

  testWidgets('masque le rappel sécurité et affiche la saisie distante', (
    tester,
  ) async {
    final dynamic state = await _pumpThread(tester);

    const safetyText =
        'Ne partagez jamais de codes, mots de passe ou informations bancaires.';
    expect(find.text(safetyText), findsOneWidget);
    expect(state.showSafetyReminder, isTrue);

    await tester.tap(find.byTooltip('Masquer'));
    await tester.pump();
    expect(find.text(safetyText), findsNothing);
    expect(state.showSafetyReminder, isFalse);

    state.setState(() {
      state.otherParticipantNameState = 'Alice';
      state.otherIsTyping = true;
    });
    await tester.pump();
    expect(find.text('Alice écrit…'), findsWidgets);

    state.setState(() {
      state.otherIsTyping = false;
    });
    await tester.pump();
    expect(find.text('Alice écrit…'), findsNothing);

    final Widget todayChip = state.buildThreadDateChip(DateTime.now());
    final Widget emptyChip = state.buildThreadDateChip(null);
    await _disposeThread(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Column(children: <Widget>[todayChip, emptyChip])),
      ),
    );
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('--/--/----'), findsOneWidget);
  });
}
