import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/email_action_service.dart';

class _EmailActionMultiFactorPlatform extends MultiFactorPlatform {
  _EmailActionMultiFactorPlatform(super.auth);
}

class _EmailActionUserPlatform extends UserPlatform {
  _EmailActionUserPlatform(
    FirebaseAuthPlatform auth, {
    required String uid,
    required String? email,
    required bool emailVerified,
    this.reloadError,
    this.onReload,
  }) : super(
          auth,
          _EmailActionMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: email,
              displayName: 'Utilisateur email',
              isAnonymous: false,
              isEmailVerified: emailVerified,
              creationTimestamp:
                  DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 19).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  final Object? reloadError;
  final void Function()? onReload;
  var reloadCalls = 0;
  var tokenCalls = 0;
  bool? lastForceRefresh;

  @override
  Future<void> reload() async {
    reloadCalls += 1;
    onReload?.call();
    final error = reloadError;
    if (error != null) throw error;
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    tokenCalls += 1;
    lastForceRefresh = forceRefresh;
    return 'email-action-token';
  }
}

class _EmailActionAuthPlatform extends FirebaseAuthPlatform {
  _EmailActionAuthPlatform() : super(appInstance: null);

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _EmailActionAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    platform = _EmailActionAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform.user = null;
  });

  tearDown(EmailActionService.resetCallableInvokerForTest);

  _EmailActionUserPlatform signIn({
    String uid = 'email-action-user',
    String? email = 'personne@example.com',
    bool emailVerified = true,
    Object? reloadError,
    void Function()? onReload,
  }) {
    final user = _EmailActionUserPlatform(
      platform,
      uid: uid,
      email: email,
      emailVerified: emailVerified,
      reloadError: reloadError,
      onReload: onReload,
    );
    platform.user = user;
    return user;
  }

  test('normalise l email et appelle le reset backend', () async {
    String? functionName;
    Map<String, dynamic>? payload;
    EmailActionService.setCallableInvokerForTest((name, data) async {
      functionName = name;
      payload = data;
    });

    await EmailActionService.requestPasswordResetEmail(
      '  Personne@Example.com  ',
    );

    expect(functionName, 'requestPasswordResetEmail');
    expect(payload, <String, dynamic>{'email': 'Personne@Example.com'});
  });

  test('demande une vérification email sans payload', () async {
    String? functionName;
    Map<String, dynamic>? payload = <String, dynamic>{};
    EmailActionService.setCallableInvokerForTest((name, data) async {
      functionName = name;
      payload = data;
    });

    await EmailActionService.requestEmailVerificationEmail();

    expect(functionName, 'requestEmailVerificationEmail');
    expect(payload, isNull);
  });

  test('signale le changement de mot de passe avec un timestamp courant',
      () async {
    String? functionName;
    Map<String, dynamic>? payload;
    EmailActionService.setCallableInvokerForTest((name, data) async {
      functionName = name;
      payload = data;
    });
    final before = DateTime.now().millisecondsSinceEpoch;

    await EmailActionService.reportPasswordChanged();

    final after = DateTime.now().millisecondsSinceEpoch;
    expect(functionName, 'reportPasswordChanged');
    expect(payload, isNotNull);
    expect(payload!['changedAt'], isA<int>());
    expect(payload!['changedAt'] as int, inInclusiveRange(before, after));
  });

  test('propage les erreurs du backend', () async {
    EmailActionService.setCallableInvokerForTest((_, __) async {
      throw StateError('backend indisponible');
    });

    await expectLater(
      EmailActionService.requestEmailVerificationEmail(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'backend indisponible',
        ),
      ),
    );
  });

  test('retourne false sans utilisateur connecté', () async {
    final result =
        await EmailActionService.syncCurrentUserEmailVerificationState(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
    );

    expect(result, isFalse);
  });

  test('retourne false pour un email absent ou non vérifié', () async {
    final firestore = FakeFirebaseFirestore();
    final user = signIn(email: '   ', emailVerified: false);

    final result =
        await EmailActionService.syncCurrentUserEmailVerificationState(
      auth: auth,
      firestore: firestore,
    );

    expect(result, isFalse);
    expect(user.reloadCalls, 1);
    expect(user.tokenCalls, 0);
    expect(
      (await firestore.collection('users').doc('email-action-user').get())
          .exists,
      isFalse,
    );
  });

  test('synchronise un email vérifié malgré une erreur de reload', () async {
    final firestore = FakeFirebaseFirestore();
    final user = signIn(
      uid: 'verified-email-user',
      email: '  PERSONNE@Example.COM  ',
      reloadError: StateError('reload indisponible'),
    );
    final userRef = firestore.collection('users').doc(user.uid);
    await userRef.set(<String, dynamic>{
      'existing': 'conservé',
      'email_verified': false,
      'isEmailVerified': false,
    });

    final result =
        await EmailActionService.syncCurrentUserEmailVerificationState(
      auth: auth,
      firestore: firestore,
    );
    final data = (await userRef.get()).data()!;

    expect(result, isTrue);
    expect(user.reloadCalls, 1);
    expect(user.tokenCalls, 1);
    expect(user.lastForceRefresh, isTrue);
    expect(data['uid'], 'verified-email-user');
    expect(data['email'], 'personne@example.com');
    expect(data['emailVerified'], isTrue);
    expect(data['existing'], 'conservé');
    expect(data.containsKey('email_verified'), isFalse);
    expect(data.containsKey('isEmailVerified'), isFalse);
    expect(data['updatedAt'], isNotNull);
  });

  test('utilise l utilisateur initial si la session disparaît après reload',
      () async {
    final firestore = FakeFirebaseFirestore();
    late _EmailActionUserPlatform user;
    user = signIn(
      uid: 'fallback-email-user',
      email: 'fallback@example.com',
      onReload: () => platform.user = null,
    );

    final result =
        await EmailActionService.syncCurrentUserEmailVerificationState(
      auth: auth,
      firestore: firestore,
    );
    final data = (await firestore.collection('users').doc(user.uid).get()).data();

    expect(result, isTrue);
    expect(user.tokenCalls, 1);
    expect(data?['email'], 'fallback@example.com');
  });
}
