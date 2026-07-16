import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _ThreadMultiFactorPlatform extends MultiFactorPlatform {
  _ThreadMultiFactorPlatform(super.auth);
}

class _ThreadUserPlatform extends UserPlatform {
  _ThreadUserPlatform(
    FirebaseAuthPlatform auth, {
    required this.tokenCompleter,
  }) : super(
          auth,
          _ThreadMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'thread-user',
              email: 'thread-user@ilipresto.fr',
              displayName: 'Utilisateur conversation',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 16).millisecondsSinceEpoch,
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

  final Completer<String?> tokenCompleter;
  int reloadCalls = 0;

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) => tokenCompleter.future;
}

class _ThreadAuthPlatform extends FirebaseAuthPlatform {
  _ThreadAuthPlatform() : super(appInstance: null);

  UserPlatform? user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ThreadAuthPlatform authPlatform;
  late _ThreadUserPlatform userPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _ThreadAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    userPlatform = _ThreadUserPlatform(
      authPlatform,
      tokenCompleter: Completer<String?>(),
    );
    authPlatform.user = userPlatform;
  });

  Future<void> pumpThread(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationThreadPage(
          conversationId: 'conversation-1',
          offerTitle: 'Peinture salon',
          currentUserId: 'thread-user',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> disposeThread(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    if (!userPlatform.tokenCompleter.isCompleted) {
      userPlatform.tokenCompleter.completeError(
        StateError('Fin déterministe du test de conversation'),
      );
    }
    await tester.pump();
    await tester.pump();
  }

  tearDown(() {
    authPlatform.user = null;
  });

  testWidgets('affiche et manipule le shell principal de la conversation',
      (tester) async {
    await pumpThread(tester);

    expect(find.text('Peinture salon'), findsWidgets);
    expect(find.text('Chargement...'), findsOneWidget);
    expect(
      find.text('Preparation securisee de la messagerie…'),
      findsOneWidget,
    );
    expect(find.text('Annonce liée à la conversation'), findsOneWidget);
    expect(find.text('Votre message...'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(userPlatform.reloadCalls, 1);

    await tester.tap(find.byTooltip('Réduire'));
    await tester.pump();
    expect(find.byTooltip('Déplier'), findsOneWidget);
    expect(find.text('Annonce liée à la conversation'), findsNothing);

    await tester.tap(find.byTooltip('Déplier'));
    await tester.pump();
    expect(find.text('Annonce liée à la conversation'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Archiver'), findsOneWidget);
    expect(find.text('Bloquer'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Ajouter une pièce jointe'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Fichier'), findsOneWidget);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Emoji'));
    await tester.pump();
    expect(find.text('👍'), findsOneWidget);
    expect(find.text('🙏'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bonjour');
    await tester.pump();
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

    await disposeThread(tester);
  });

  testWidgets('refuse les actions d’envoi lorsque la session disparaît',
      (tester) async {
    await pumpThread(tester);
    authPlatform.user = null;

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    expect(
      find.text('Connectez-vous pour envoyer une note vocale.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Ajouter une pièce jointe'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Photo'));
    await tester.pump();
    expect(
      find.text('Connectez-vous pour envoyer une photo.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Ajouter une pièce jointe'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Fichier'));
    await tester.pump();
    expect(
      find.text('Connectez-vous pour envoyer un fichier.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Message sans session');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(
      find.text('Connectez-vous pour envoyer un message.'),
      findsOneWidget,
    );

    await disposeThread(tester);
  });
}
