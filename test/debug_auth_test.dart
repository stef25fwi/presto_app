import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/debug_auth.dart';

class _DebugCredentialPlatform extends UserCredentialPlatform {
  _DebugCredentialPlatform({required super.auth}) : super(user: null);
}

class _DebugAuthPlatform extends FirebaseAuthPlatform {
  _DebugAuthPlatform() : super(appInstance: null);

  final authController = StreamController<UserPlatform?>.broadcast();
  final tokenController = StreamController<UserPlatform?>.broadcast();
  Object? providerError;
  var providerCalls = 0;

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
  Stream<UserPlatform?> authStateChanges() => authController.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => tokenController.stream;

  @override
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    providerCalls += 1;
    final error = providerError;
    if (error != null) throw error;
    return _DebugCredentialPlatform(auth: this);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _DebugAuthPlatform platform;
  late List<String> logs;
  late DebugPrintCallback previousDebugPrint;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _DebugAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform
      ..providerError = null
      ..providerCalls = 0;
    logs = <String>[];
    previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() {
    debugPrint = previousDebugPrint;
  });

  tearDownAll(() async {
    await platform.authController.close();
    await platform.tokenController.close();
  });

  test('installAuthStateLogs journalise les sessions absentes', () async {
    DebugAuth.installAuthStateLogs();

    platform.authController.add(null);
    platform.tokenController.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(
      logs,
      contains('[AUTH] authStateChanges: authenticated=false'),
    );
    expect(
      logs,
      contains('[AUTH] idTokenChanges: user=null token=null'),
    );
  });

  test('installAuthStateLogs journalise les erreurs de flux', () async {
    DebugAuth.installAuthStateLogs();

    platform.authController.addError(StateError('auth stream'));
    platform.tokenController.addError(StateError('token stream'));
    await Future<void>.delayed(Duration.zero);

    expect(logs.any((line) => line.contains('authStateChanges ERROR')), isTrue);
    expect(logs.any((line) => line.contains('idTokenChanges ERROR')), isTrue);
  });

  test('debugRedirectResultAtStartup ne fait rien hors web', () async {
    await DebugAuth.debugRedirectResultAtStartup();
    expect(logs, isEmpty);
  });

  test('signInGoogleDebug utilise le provider natif', () async {
    await DebugAuth.signInGoogleDebug();

    expect(platform.providerCalls, 1);
    expect(
      logs,
      contains('[AUTH] signInWithProvider() start'),
    );
    expect(
      logs,
      contains('[AUTH] signInWithProvider() success uid=null'),
    );
  });

  test('signInGoogleDebug journalise une erreur Firebase', () async {
    platform.providerError = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'offline',
    );

    await DebugAuth.signInGoogleDebug();

    expect(platform.providerCalls, 1);
    expect(
      logs.any((line) => line.contains('network-request-failed')),
      isTrue,
    );
  });

  test('signInGoogleDebug journalise une erreur inattendue', () async {
    platform.providerError = StateError('provider unavailable');

    await DebugAuth.signInGoogleDebug();

    expect(platform.providerCalls, 1);
    expect(logs.any((line) => line.contains('signIn ERROR')), isTrue);
  });
}
