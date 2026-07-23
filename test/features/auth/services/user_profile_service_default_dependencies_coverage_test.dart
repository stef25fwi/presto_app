import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/services/user_profile_service.dart';

void main() {
  test('construit les dépendances de production et exerce le bootstrap par défaut',
      () async {
    final productionDefaults = AuthUserProfileService();
    expect(productionDefaults, isA<AuthUserProfileService>());

    final user = _ProfileUser(
      uidValue: 'default-bootstrap-user',
      emailValue: ' USER@EXAMPLE.FR ',
      emailVerifiedValue: true,
    );
    var bootstrapCalls = 0;
    Map<String, dynamic>? written;
    final service = AuthUserProfileService(
      defaultBootstrapUserProfile: ({
        required user,
        required authMethod,
        required isNewUserHint,
        required forceRefresh,
      }) async {
        bootstrapCalls += 1;
        expect(user.uid, 'default-bootstrap-user');
        expect(authMethod, 'email');
        expect(isNewUserHint, isTrue);
        expect(forceRefresh, isTrue);
      },
      writeUserDocument: ({required uid, required data}) async {
        expect(uid, 'default-bootstrap-user');
        written = data;
      },
    );

    await service.ensureEmailUserProfile(
      user: user,
      displayName: ' Profil par défaut ',
      isBusinessAccount: false,
    );

    expect(bootstrapCalls, 1);
    expect(written?['email'], 'user@example.fr');
    expect(written?['displayName'], 'Profil par défaut');
    expect(written?['updatedAt'], isA<FieldValue>());
    expect(written?['lastLoginAt'], same(written?['updatedAt']));
  });

  test('exerce la préparation d accès par défaut injectable', () async {
    final user = _ProfileUser(
      uidValue: 'default-prepare-user',
      emailValue: 'pro@example.fr',
      emailVerifiedValue: false,
    );
    var prepareCalls = 0;
    Map<String, dynamic>? written;
    final service = AuthUserProfileService(
      timestampFactory: () => 'fixed-time',
      defaultPrepareProfileAccess: ({
        required user,
        required forceRefreshToken,
        required forceRefreshAppCheckToken,
      }) async {
        prepareCalls += 1;
        expect(user.uid, 'default-prepare-user');
        expect(forceRefreshToken, isTrue);
        expect(forceRefreshAppCheckToken, isTrue);
      },
      businessProfileExists: (_) async => false,
      writeBusinessProfile: ({required uid, required data}) async {
        expect(uid, 'default-prepare-user');
        written = data;
      },
    );

    await service.ensureBusinessProfileDraft(
      user: user,
      displayName: ' Entreprise test ',
    );

    expect(prepareCalls, 1);
    expect(written?['contactName'], 'Entreprise test');
    expect(written?['contactEmail'], 'pro@example.fr');
    expect(written?['status'], 'pending');
    expect(written?['createdAt'], 'fixed-time');
  });
}

class _ProfileUser implements User {
  _ProfileUser({
    required this.uidValue,
    required this.emailValue,
    required this.emailVerifiedValue,
  });

  final String uidValue;
  final String? emailValue;
  final bool emailVerifiedValue;

  @override
  String get uid => uidValue;

  @override
  String? get email => emailValue;

  @override
  bool get emailVerified => emailVerifiedValue;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
