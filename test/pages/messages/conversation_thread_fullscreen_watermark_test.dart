import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/messages/conversation_thread_page.dart';

class _FullscreenMultiFactorPlatform extends MultiFactorPlatform {
  _FullscreenMultiFactorPlatform(super.auth);
}

class _FullscreenTokenResult extends IdTokenResult {
  _FullscreenTokenResult()
      : super(
          InternalIdTokenResult(
            token: 'messaging-fullscreen-token',
            claims: const <String?, Object?>{'admin': true},
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _FullscreenUserPlatform extends UserPlatform {
  _FullscreenUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _FullscreenMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'fullscreen-user',
              email: 'fullscreen-user@ilipresto.fr',
              displayName: 'Utilisateur plein écran',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 8, 3).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': 'fullscreen-user',
                'email': 'fullscreen-user@ilipresto.fr',
                'displayName': 'Utilisateur plein écran',
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
      'messaging-fullscreen-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async =>
      _FullscreenTokenResult();
}

class _FullscreenAuthPlatform extends FirebaseAuthPlatform {
  _FullscreenAuthPlatform() : super(appInstance: null);

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
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> idTokenChanges() =>
      Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

Future<dynamic> _pumpThread(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  await tester.pumpWidget(
    const MaterialApp(
      home: ConversationThreadPage(
        conversationId: 'conversation-fullscreen-watermark',
        offerTitle: 'Photo conversation',
        currentUserId: 'fullscreen-user',
      ),
    ),
  );

  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(TextField).evaluate().isNotEmpty) {
      return tester.state(find.byType(ConversationThreadPage));
    }
  }
  fail('Le fil de discussion ne s’est pas affiché.');
}

OverlayEntry _mountPreviewInOverlay(dynamic state, Widget preview) {
  final overlay = Overlay.of(state.context);
  final entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Center(child: preview),
      ),
    ),
  );
  overlay.insert(entry);
  return entry;
}

Finder _dismissibleModalBarrier() => find.byWidgetPredicate(
  (widget) => widget is ModalBarrier && widget.dismissible,
  description: 'barrière modale fermable',
);

Future<void> _disposeThread(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FullscreenAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    authPlatform = _FullscreenAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user = _FullscreenUserPlatform(authPlatform);
  });

  tearDown(() {
    authPlatform.user = null;
  });

  testWidgets(
    'ouvre une photo en plein écran avec zoom, watermark et fermeture',
    (tester) async {
      final dynamic state = await _pumpThread(tester);
      const attachment = MessageAttachment(
        type: 'image',
        name: 'photo-test.webp',
        url: '',
        thumbnailUrl: '',
        storagePath: 'messages/photo-test.webp',
        mimeType: 'image/webp',
        sizeBytes: 512,
      );
      final Widget preview = state.buildAttachmentPreview(attachment);
      final entry = _mountPreviewInOverlay(state, preview);
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.text('iliprestō'), findsNothing);

      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.minScale, 0.5);
      expect(viewer.maxScale, 4.0);
      expect(find.text('iliprestō'), findsOneWidget);
      expect(find.byTooltip('Fermer'), findsOneWidget);

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.text('iliprestō'), findsNothing);

      entry.remove();
      await _disposeThread(tester);
    },
  );

  testWidgets('le dialogue plein écran se ferme via la barrière', (
    tester,
  ) async {
    final dynamic state = await _pumpThread(tester);
    const attachment = MessageAttachment(
      type: 'image',
      name: 'photo-barriere.webp',
      url: '',
      thumbnailUrl: '',
      storagePath: 'messages/photo-barriere.webp',
      mimeType: 'image/webp',
      sizeBytes: 256,
    );
    final Widget preview = state.buildAttachmentPreview(attachment);
    final entry = _mountPreviewInOverlay(state, preview);
    await tester.pump();

    await tester.tap(find.byType(GestureDetector).last);
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    final barrierFinder = _dismissibleModalBarrier();
    expect(barrierFinder, findsOneWidget);
    final barrier = tester.widget<ModalBarrier>(barrierFinder);
    expect(barrier.onDismiss, isNotNull);
    barrier.onDismiss!.call();
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsNothing);

    entry.remove();
    await _disposeThread(tester);
  });
}
