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

class _ThreadTokenResult extends IdTokenResult {
  _ThreadTokenResult()
      : super(
          InternalIdTokenResult(
            token: 'thread-test-token',
            claims: const <String?, Object?>{'admin': true},
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
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

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    return _ThreadTokenResult();
  }
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

void _drainExpectedConversationThreadExceptions(WidgetTester tester) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    final message = exception.toString();
    final isExpectedCircleAvatarAssertion =
        message.contains('circle_avatar.dart') &&
        message.contains(
          'foregroundImage != null || onForegroundImageError == null',
        );
    if (!isExpectedCircleAvatarAssertion) {
      throw exception!;
    }
  }
}

Future<void> _pumpThreadFrame(
  WidgetTester tester, [
  Duration? duration,
]) async {
  if (duration == null) {
    await tester.pump();
  } else {
    await tester.pump(duration);
  }
  _drainExpectedConversationThreadExceptions(tester);
}

Future<void> _pumpUntilThreadShellIsReady(WidgetTester tester) async {
  for (var second = 0; second < 30; second += 1) {
    await _pumpThreadFrame(tester, const Duration(seconds: 1));
    if (find.text('Peinture salon').evaluate().isNotEmpty &&
        find.byType(TextField).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Le shell de conversation ne s’est pas affiché après 30 secondes simulées.');
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
    final tokenCompleter = Completer<String?>()..complete('thread-test-token');
    userPlatform = _ThreadUserPlatform(
      authPlatform,
      tokenCompleter: tokenCompleter,
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
    _drainExpectedConversationThreadExceptions(tester);
    await _pumpUntilThreadShellIsReady(tester);
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
    await _pumpThreadFrame(tester);
    expect(find.byTooltip('Déplier'), findsOneWidget);
    expect(find.text('Annonce liée à la conversation'), findsNothing);

    await tester.tap(find.byTooltip('Déplier'));
    await _pumpThreadFrame(tester);
    expect(find.text('Annonce liée à la conversation'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await _pumpThreadFrame(tester, const Duration(milliseconds: 300));
    expect(find.text('Archiver'), findsOneWidget);
    expect(find.text('Bloquer'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    await tester.pageBack();
    await _pumpThreadFrame(tester, const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Ajouter une pièce jointe'));
    await _pumpThreadFrame(tester, const Duration(milliseconds: 300));
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Fichier'), findsOneWidget);
    await tester.pageBack();
    await _pumpThreadFrame(tester, const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Emoji'));
    await _pumpThreadFrame(tester);
    expect(find.text('👍'), findsOneWidget);
    expect(find.text('🙏'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bonjour');
    await _pumpThreadFrame(tester);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await _pumpThreadFrame(tester);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpThreadFrame(tester);
  });

  testWidgets('refuse les actions d’envoi lorsque la session disparaît',
      (tester) async {
    await pumpThread(tester);
    authPlatform.user = null;

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await _pumpThreadFrame(tester);
    expect(
      find.text('Connectez-vous pour envoyer une note vocale.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Ajouter une pièce jointe'));
    await _pumpThreadFrame(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Photo'));
    await _pumpThreadFrame(tester);
    expect(
      find.text('Connectez-vous pour envoyer une photo.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Ajouter une pièce jointe'));
    await _pumpThreadFrame(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Fichier'));
    await _pumpThreadFrame(tester);
    expect(
      find.text('Connectez-vous pour envoyer un fichier.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Message sans session');
    await _pumpThreadFrame(tester);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _pumpThreadFrame(tester);
    expect(
      find.text('Connectez-vous pour envoyer un message.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpThreadFrame(tester);
  });
}
