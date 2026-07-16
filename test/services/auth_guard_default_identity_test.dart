import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/account_page.dart';
import 'package:presto_app/pages/auth/verify_email_page.dart';
import 'package:presto_app/services/auth_guard.dart';

class _TestMultiFactorPlatform extends MultiFactorPlatform {
  _TestMultiFactorPlatform(super.auth);
}

class _GuardUserPlatform extends UserPlatform {
  _GuardUserPlatform(
    FirebaseAuthPlatform auth, {
    required String uid,
    required bool emailVerified,
    required String providerId,
  }) : super(
          auth,
          _TestMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: '$uid@ilipresto.fr',
              displayName: 'Utilisateur test',
              isAnonymous: false,
              isEmailVerified: emailVerified,
              creationTimestamp:
                  DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 16).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': providerId,
                'uid': uid,
                'email': '$uid@ilipresto.fr',
                'displayName': 'Utilisateur test',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': emailVerified,
              },
            ],
          ),
        );

  var reloadCalls = 0;

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }
}

class _GuardAuthPlatform extends FirebaseAuthPlatform {
  _GuardAuthPlatform() : super(appInstance: null);

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

class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? pushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) pushedRoute = route;
    super.didPush(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GuardAuthPlatform platform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _GuardAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform.user = null;
  });

  Future<({BuildContext context, _RecordingNavigatorObserver observer})>
      pumpHarness(WidgetTester tester) async {
    late BuildContext guardedContext;
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[observer],
        home: Builder(
          builder: (context) {
            guardedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    return (context: guardedContext, observer: observer);
  }

  testWidgets('utilise Firebase et prépare AccountPage sans session',
      (tester) async {
    final harness = await pumpHarness(tester);

    final allowed = await AuthGuard.requireVerifiedEmail(harness.context);

    expect(allowed, isFalse);
    final route = harness.observer.pushedRoute;
    expect(route, isA<MaterialPageRoute<dynamic>>());
    expect(
      (route! as MaterialPageRoute<dynamic>).builder(harness.context),
      isA<AccountPage>(),
    );
  });

  testWidgets('utilise Firebase et prépare VerifyEmailPage pour un mot de passe',
      (tester) async {
    final current = _GuardUserPlatform(
      platform,
      uid: 'password-user',
      emailVerified: false,
      providerId: 'password',
    );
    platform.user = current;
    final harness = await pumpHarness(tester);

    final allowed = await AuthGuard.requireVerifiedEmail(harness.context);

    expect(allowed, isFalse);
    expect(current.reloadCalls, 1);
    final route = harness.observer.pushedRoute;
    expect(route, isA<MaterialPageRoute<dynamic>>());
    expect(
      (route! as MaterialPageRoute<dynamic>).builder(harness.context),
      isA<VerifyEmailPage>(),
    );
  });

  testWidgets('autorise un mot de passe Firebase déjà vérifié', (tester) async {
    final current = _GuardUserPlatform(
      platform,
      uid: 'verified-user',
      emailVerified: true,
      providerId: 'password',
    );
    platform.user = current;
    final harness = await pumpHarness(tester);

    final allowed = await AuthGuard.requireVerifiedEmail(harness.context);

    expect(allowed, isTrue);
    expect(current.reloadCalls, 1);
    expect(harness.observer.pushedRoute, isNull);
  });
}
