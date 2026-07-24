import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _StaleMultiFactorPlatform extends MultiFactorPlatform {
  _StaleMultiFactorPlatform(super.auth);
}

class _StaleTokenResult extends IdTokenResult {
  _StaleTokenResult()
      : super(
          InternalIdTokenResult(
            token: 'admin-token',
            claims: <String?, Object?>{
              'roles': <String>['admin'],
              'primaryRole': 'admin',
            },
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 7, 24).millisecondsSinceEpoch,
            expirationTimestamp:
                DateTime(2027, 7, 24).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _StaleUserPlatform extends UserPlatform {
  _StaleUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _StaleMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'stale-admin-user',
              email: 'stale-admin@ilipresto.fr',
              displayName: 'Stale Admin',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 24).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  final List<bool> tokenRequests = <bool>[];
  final List<bool> tokenResultRequests = <bool>[];

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    tokenRequests.add(forceRefresh);
    return forceRefresh ? 'fresh-admin-token' : 'cached-admin-token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    tokenResultRequests.add(forceRefresh);
    return _StaleTokenResult();
  }
}

class _StaleAuthPlatform extends FirebaseAuthPlatform {
  _StaleAuthPlatform() : super(appInstance: null) {
    user = _StaleUserPlatform(this);
  }

  late final _StaleUserPlatform user;

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
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

class _StaleFunctions implements FirebaseFunctions {
  final _StaleCallable callable = _StaleCallable();
  String? requestedName;
  HttpsCallableOptions? requestedOptions;

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) {
    requestedName = name;
    requestedOptions = options;
    return callable;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaleCallable implements HttpsCallable {
  var calls = 0;
  Object? error;
  final List<dynamic> receivedParameters = <dynamic>[];

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    calls += 1;
    receivedParameters.add(parameters);
    final currentError = error;
    if (currentError != null) throw currentError;
    return _StaleCallableResult<T>(
      <String, dynamic>{
        'isAdmin': false,
        'source': 'custom-claims',
        'checkedAt': 1784937600000,
        'debug': <String, dynamic>{
          'adminDocExists': true,
          'adminDocEnabled': false,
        },
      } as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaleCallableResult<T> implements HttpsCallableResult<T> {
  const _StaleCallableResult(this.data);

  @override
  final T data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StaleAuthPlatform authPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _StaleAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
  });

  setUp(() {
    authPlatform.user
      ..tokenRequests.clear()
      ..tokenResultRequests.clear();
  });

  AdminAccessResolver resolverFor(_StaleFunctions functions) {
    return AdminAccessResolver(
      auth: FirebaseAuth.instance,
      firestore: FakeFirebaseFirestore(),
      functions: functions,
    );
  }

  test('rafraîchit les claims et marque un refus serveur persistant', () async {
    final functions = _StaleFunctions();
    final state = await resolverFor(functions).resolveAdminAccess();

    expect(functions.requestedName, 'getMyAdminAccessStatus');
    expect(functions.requestedOptions?.timeout, const Duration(seconds: 15));
    expect(functions.callable.calls, 2);
    expect(
      functions.callable.receivedParameters,
      <dynamic>[const <String, dynamic>{}, const <String, dynamic>{}],
    );
    expect(authPlatform.user.tokenRequests.where((value) => value), isNotEmpty);
    expect(authPlatform.user.tokenResultRequests, contains(true));
    expect(state.tokenHasAdmin, isTrue);
    expect(state.profileHasAdmin, isTrue);
    expect(state.serverCheckSucceeded, isTrue);
    expect(state.serverIsAdmin, isFalse);
    expect(state.serverSource, 'custom-claims');
    expect(state.adminDocLoaded, isTrue);
    expect(state.adminDocHasAdmin, isFalse);
    expect(state.serverErrorCode, 'stale-claims');
    expect(state.effectiveIsAdmin, isTrue);
    expect(state.sourceOfTruth, 'token');
    expect(state.lastStage, 'finished');
    expect(
      state.debugSteps.any((step) => step.contains('stale-claims persists')),
      isTrue,
    );
  });

  test('expose une erreur Functions indisponible sans retry HTTP', () async {
    final functions = _StaleFunctions()
      ..callable.error = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'service admin indisponible',
      );

    final state = await resolverFor(functions).resolveAdminAccess();

    expect(functions.callable.calls, 1);
    expect(state.serverCheckAttempted, isTrue);
    expect(state.serverCheckSucceeded, isFalse);
    expect(state.serverIsAdmin, isNull);
    expect(state.serverErrorCode, 'unavailable');
    expect(state.serverErrorMessage, isNotEmpty);
    expect(state.effectiveIsAdmin, isTrue);
    expect(state.sourceOfTruth, 'token');
  });

  test('normalise une erreur callable inconnue', () async {
    final functions = _StaleFunctions()
      ..callable.error = StateError('réponse serveur illisible');

    final state = await resolverFor(functions).resolveAdminAccess();

    expect(functions.callable.calls, 1);
    expect(state.serverCheckAttempted, isTrue);
    expect(state.serverCheckSucceeded, isFalse);
    expect(state.serverIsAdmin, isNull);
    expect(state.serverErrorCode, 'unknown');
    expect(state.serverErrorMessage, contains('réponse serveur illisible'));
    expect(state.effectiveIsAdmin, isTrue);
    expect(state.sourceOfTruth, 'token');
  });
}
