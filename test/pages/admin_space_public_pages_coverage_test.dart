// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_space_page.dart';

class _SignedOutAdminSpaceAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutAdminSpaceAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream<UserPlatform?>.value(null);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuthPlatform originalAuthPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:admin-space-public-coverage',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    originalAuthPlatform = FirebaseAuthPlatform.instance;
  });

  setUp(() {
    FirebaseAuthPlatform.instance = _SignedOutAdminSpaceAuthPlatform();
  });

  tearDown(() {
    FirebaseAuthPlatform.instance = originalAuthPlatform;
  });

  test('convertit toutes les qualités audio Micro-IA', () {
    expect(
      microIaAudioQualityToRcValue(MicroIaAudioQuality.low),
      'LOW',
    );
    expect(
      microIaAudioQualityToRcValue(MicroIaAudioQuality.medium),
      'MEDIUM',
    );
    expect(
      microIaAudioQualityToRcValue(MicroIaAudioQuality.high),
      'HIGH',
    );
    expect(
      microIaAudioQualityFromRcValue('low'),
      MicroIaAudioQuality.low,
    );
    expect(
      microIaAudioQualityFromRcValue('HIGH'),
      MicroIaAudioQuality.high,
    );
    expect(
      microIaAudioQualityFromRcValue('unknown'),
      MicroIaAudioQuality.medium,
    );
  });

  testWidgets('MicroIaTranscription rend puis traverse ses contrôles locaux',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: MicroIaTranscriptionPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();

    expect(find.text('Micro-IA — Transcription'), findsWidgets);
    expect(find.text('Google STT'), findsOneWidget);
    expect(find.text('Whisper'), findsOneWidget);
    expect(find.text('Hybride'), findsOneWidget);
    expect(find.text('Qualité audio'), findsOneWidget);
    expect(find.text('Fallback'), findsOneWidget);
    expect(find.text('fr-FR'), findsOneWidget);

    await tester.tap(find.text('Google STT'));
    await tester.pump();
    await tester.tap(find.text('Whisper'));
    await tester.pump();
    await tester.tap(find.text('Hybride'));
    await tester.pump();

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));
    tester.widget<Switch>(switches.at(0)).onChanged?.call(true);
    await tester.pump();
    tester.widget<Switch>(switches.at(1)).onChanged?.call(false);
    await tester.pump();

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(0.83);
    await tester.pump();
    expect(find.text('0.83'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await tester.pump();
    expect(find.text('Ajouter une langue (à brancher)'), findsOneWidget);

    final close = find.byIcon(Icons.close_rounded);
    expect(close, findsOneWidget);
    await tester.tap(close);
    await tester.pump();
    expect(find.text('fr-FR'), findsNothing);

    await tester.tap(find.text('Basse'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final save = find.text('Enregistrer les changements');
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmailDashboard traverse les fenêtres et gère le backend indisponible',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: EmailDashboardPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Dashboard email'), findsOneWidget);
    expect(find.text('1 h'), findsOneWidget);
    expect(find.text('24 h'), findsOneWidget);
    expect(find.text('7 j'), findsOneWidget);

    await tester.tap(find.text('24 h'));
    await tester.pump();
    await tester.tap(find.text('7 j'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
