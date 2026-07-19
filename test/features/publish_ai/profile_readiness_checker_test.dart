import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/publish_ai/profile_readiness.dart';

class _ProfileMultiFactorPlatform extends MultiFactorPlatform {
  _ProfileMultiFactorPlatform(super.auth);
}

class _ProfileUserPlatform extends UserPlatform {
  _ProfileUserPlatform(
    FirebaseAuthPlatform auth, {
    required String uid,
    required String? displayName,
  }) : super(
          auth,
          _ProfileMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: '$uid@ilipresto.fr',
              displayName: displayName,
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 18).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );
}

class _ProfileAuthPlatform extends FirebaseAuthPlatform {
  _ProfileAuthPlatform() : super(appInstance: null);

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
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(currentUser);

  @override
  Stream<UserPlatform?> userChanges() =>
      Stream<UserPlatform?>.value(currentUser);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ProfileAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    platform = _ProfileAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform.user = null;
  });

  User signIn({
    String uid = 'profile-user-1',
    String? displayName = 'Stef',
  }) {
    platform.user = _ProfileUserPlatform(
      platform,
      uid: uid,
      displayName: displayName,
    );
    return auth.currentUser!;
  }

  ProfileAccessPreparer successfulPreparation(User user) {
    return ({
      required User user,
      required bool forceRefreshAppCheckToken,
    }) async {
      expect(forceRefreshAppCheckToken, isTrue);
      return user;
    };
  }

  test('bloque immédiatement un utilisateur déconnecté', () async {
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
    );

    final result = await checker.check();

    expect(result.isReady, isFalse);
    expect(result.gate, ProfileReadinessGate.signedOut);
    expect(result.user, isNull);
    expect(result.describe(), "Connecte-toi pour utiliser la dictée IA.");
  });

  test('convertit un échec de préparation du profil en résultat lisible',
      () async {
    signIn();
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
      accessPreparer: ({
        required User user,
        required bool forceRefreshAppCheckToken,
      }) async {
        throw FirebaseException(
          plugin: 'firebase_auth',
          code: 'permission-denied',
          message: 'profile access unavailable in this test',
        );
      },
    );

    final result = await checker.check();

    expect(result.isReady, isFalse);
    expect(result.gate, ProfileReadinessGate.readFailed);
    expect(result.user?.uid, 'profile-user-1');
    expect(result.errorDetail, contains('permission-denied'));
    expect(result.describe(), isNotEmpty);
  });

  test('signale un document de profil absent', () async {
    final user = signIn();
    final firestore = FakeFirebaseFirestore();
    final missingSnapshot =
        await firestore.collection('users').doc(user.uid).get();
    final sources = <Source>[];
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: firestore,
      accessPreparer: successfulPreparation(user),
      documentReader: ({required String uid, required Source source}) async {
        sources.add(source);
        return missingSnapshot;
      },
    );

    final result = await checker.check();

    expect(result.isReady, isFalse);
    expect(result.gate, ProfileReadinessGate.profileMissing);
    expect(result.user?.uid, user.uid);
    expect(sources, <Source>[Source.server]);
  });

  test('valide un profil complet lu depuis le serveur', () async {
    final user = signIn();
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'pseudo': 'Stef',
      'city': 'Baie-Mahault',
      'postalCode': '97122',
    });
    final snapshot = await firestore.collection('users').doc(user.uid).get();
    final sources = <Source>[];
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: firestore,
      accessPreparer: successfulPreparation(user),
      documentReader: ({required String uid, required Source source}) async {
        sources.add(source);
        return snapshot;
      },
    );

    final result = await checker.check();

    expect(result.isReady, isTrue);
    expect(result.gate, isNull);
    expect(result.user?.uid, user.uid);
    expect(result.describe(), 'Profil prêt.');
    expect(sources, <Source>[Source.server]);
  });

  test('se replie sur le cache après un échec serveur', () async {
    final user = signIn();
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'displayName': 'Stef',
      'ville': 'Les Abymes',
      'codePostal': '97139',
    });
    final cachedSnapshot =
        await firestore.collection('users').doc(user.uid).get();
    final sources = <Source>[];
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: firestore,
      accessPreparer: successfulPreparation(user),
      documentReader: ({required String uid, required Source source}) async {
        sources.add(source);
        if (source == Source.server) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'server unavailable',
          );
        }
        return cachedSnapshot;
      },
    );

    final result = await checker.check();

    expect(result.isReady, isTrue);
    expect(sources, <Source>[Source.server, Source.cache]);
  });

  test('retourne readFailed lorsque serveur et cache échouent', () async {
    final user = signIn();
    final firestore = FakeFirebaseFirestore();
    final sources = <Source>[];
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: firestore,
      accessPreparer: successfulPreparation(user),
      documentReader: ({required String uid, required Source source}) async {
        sources.add(source);
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: source == Source.server ? 'unavailable' : 'cache-miss',
          message: source.name,
        );
      },
    );

    final result = await checker.check();

    expect(result.isReady, isFalse);
    expect(result.gate, ProfileReadinessGate.readFailed);
    expect(result.errorDetail, contains('unavailable'));
    expect(result.user?.uid, user.uid);
    expect(sources, <Source>[Source.server, Source.cache]);
  });

  test('énumère les champs obligatoires absents', () async {
    final user = signIn(displayName: null);
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'displayName': ' ',
      'city': '',
    });
    final snapshot = await firestore.collection('users').doc(user.uid).get();
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: firestore,
      accessPreparer: successfulPreparation(user),
      documentReader: ({required String uid, required Source source}) async =>
          snapshot,
    );

    final result = await checker.check();

    expect(result.isReady, isFalse);
    expect(result.gate, ProfileReadinessGate.fieldsMissing);
    expect(
      result.missingFields,
      <String>['displayName', 'city', 'postalCode'],
    );
    expect(result.describe(), contains('pseudo, ville, code postal'));
  });

  test('accepte le displayName Firebase pour un profil legacy', () async {
    final user = signIn(displayName: 'Nom Firebase');
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'commune': 'Petit-Bourg',
      'postal_code': '97170',
    });
    final snapshot = await firestore.collection('users').doc(user.uid).get();
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: firestore,
      accessPreparer: successfulPreparation(user),
      documentReader: ({required String uid, required Source source}) async =>
          snapshot,
    );

    final result = await checker.check();

    expect(result.isReady, isTrue);
    expect(result.user?.displayName, 'Nom Firebase');
  });
}
