import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/core/firebase_contract.dart';
import 'package:presto_app/pages/messages/conversations_list_page.dart';

class _SignedOutAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutAuthPlatform() : super(appInstance: null);

  final StreamController<UserPlatform?> controller =
      StreamController<UserPlatform?>.broadcast();

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
  Stream<UserPlatform?> authStateChanges() => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SignedOutAuthPlatform platform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _SignedOutAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  tearDownAll(() async {
    await platform.controller.close();
  });

  test('le contrat de requête utilisateur cible participantIds', () {
    final shape = ConversationsQueryContract.shape(
      isAdminMode: false,
      userId: 'user-123',
    );

    expect(shape['collection'], FirestoreCollections.conversations);
    expect(shape['orderBy'], 'updatedAt');
    expect(shape['descending'], isTrue);
    expect(shape['participantField'], 'participantIds');
    expect(shape['participantValue'], 'user-123');
    expect(shape['limit'], isNull);
  });

  test('le contrat de requête admin active la vue globale limitée', () {
    final shape = ConversationsQueryContract.shape(
      isAdminMode: true,
      userId: 'admin-1',
    );

    expect(shape['collection'], FirestoreCollections.conversations);
    expect(shape['orderBy'], 'updatedAt');
    expect(shape['descending'], isTrue);
    expect(shape['participantField'], isNull);
    expect(shape['participantValue'], isNull);
    expect(shape['limit'], 50);
  });

  testWidgets('la page déconnectée affiche un accès messagerie explicite', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationsListPage(appBarTitle: 'Messagerie test'),
      ),
    );
    await tester.pump();

    expect(find.text('Messagerie test'), findsOneWidget);
    expect(
      find.text('Connexion / inscription pour accéder à la messagerie.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.text('ilipresto'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('la page reste déconnectée après une nouvelle émission Auth nulle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ConversationsListPage()),
    );
    platform.controller.add(null);
    await tester.pump();

    expect(find.text('Mes messages'), findsOneWidget);
    expect(
      find.text('Connexion / inscription pour accéder à la messagerie.'),
      findsOneWidget,
    );
  });
}
