import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/services/user_profile_service.dart';

void main() {
  group('AuthUserProfileService', () {
    test('écrit un profil particulier normalisé', () async {
      final user = _FakeUser(
        uidValue: 'user-1',
        emailValue: '  USER@Example.COM ',
        emailVerifiedValue: true,
      );
      Map<String, dynamic>? written;
      var bootstrapCalls = 0;
      final service = AuthUserProfileService(
        timestampFactory: () => 'now',
        bootstrapUserProfile: ({
          required user,
          required authMethod,
          required isNewUserHint,
          required forceRefresh,
        }) async {
          bootstrapCalls += 1;
          expect(authMethod, 'email');
          expect(isNewUserHint, isTrue);
          expect(forceRefresh, isTrue);
        },
        writeUserDocument: ({required uid, required data}) async {
          expect(uid, 'user-1');
          written = data;
        },
      );

      await service.ensureEmailUserProfile(
        user: user,
        displayName: '  Marie Dupont ',
        isBusinessAccount: false,
      );

      expect(bootstrapCalls, 1);
      expect(written?['email'], 'user@example.com');
      expect(written?['displayName'], 'Marie Dupont');
      expect(written?['accountType'], 'Particulier');
      expect(written?['profileKind'], 'individual');
      expect(written?['emailVerified'], isTrue);
      expect(written?['updatedAt'], 'now');
      expect(written?.containsKey('businessProfile'), isFalse);
    });

    test('crée le brouillon pro complet pour un nouveau profil', () async {
      final user = _FakeUser(
        uidValue: 'pro-1',
        emailValue: 'PRO@Example.COM',
      );
      Map<String, dynamic>? userData;
      Map<String, dynamic>? proData;
      var prepareCalls = 0;
      final service = AuthUserProfileService(
        timestampFactory: () => 'timestamp',
        bootstrapUserProfile: ({
          required user,
          required authMethod,
          required isNewUserHint,
          required forceRefresh,
        }) async {},
        prepareProfileAccess: ({
          required user,
          required forceRefreshToken,
          required forceRefreshAppCheckToken,
        }) async {
          prepareCalls += 1;
          expect(forceRefreshToken, isTrue);
          expect(forceRefreshAppCheckToken, isTrue);
        },
        writeUserDocument: ({required uid, required data}) async {
          userData = data;
        },
        businessProfileExists: (_) async => false,
        writeBusinessProfile: ({required uid, required data}) async {
          expect(uid, 'pro-1');
          proData = data;
        },
      );

      await service.ensureEmailUserProfile(
        user: user,
        displayName: '  Atelier Peyi ',
        isBusinessAccount: true,
      );

      expect(userData?['accountType'], 'Entreprise');
      expect(userData?['profileKind'], 'business');
      expect(userData?['businessProfile']['status'], 'draft');
      expect(prepareCalls, 1);
      expect(proData?['contactName'], 'Atelier Peyi');
      expect(proData?['contactEmail'], 'pro@example.com');
      expect(proData?['status'], 'pending');
      expect(proData?['plan'], 'free_pro_trial');
      expect(proData?['termsAccepted'], isFalse);
      expect(proData?['createdAt'], 'timestamp');
      expect(proData?['publicProfile']['visible'], isFalse);
    });

    test('préserve les champs d activation pour un profil pro existant',
        () async {
      final user = _FakeUser(uidValue: 'pro-existing');
      Map<String, dynamic>? proData;
      final service = AuthUserProfileService(
        timestampFactory: () => 123,
        prepareProfileAccess: ({
          required user,
          required forceRefreshToken,
          required forceRefreshAppCheckToken,
        }) async {},
        businessProfileExists: (_) async => true,
        writeBusinessProfile: ({required uid, required data}) async {
          proData = data;
        },
      );

      await service.ensureBusinessProfileDraft(
        user: user,
        displayName: 'Nom existant',
      );

      expect(proData?['contactName'], 'Nom existant');
      expect(proData?['updatedAt'], 123);
      expect(proData?.containsKey('status'), isFalse);
      expect(proData?.containsKey('plan'), isFalse);
      expect(proData?.containsKey('createdAt'), isFalse);
    });

    test('omet les emails vides des documents', () async {
      final user = _FakeUser(uidValue: 'no-email', emailValue: '   ');
      Map<String, dynamic>? userData;
      Map<String, dynamic>? proData;
      final service = AuthUserProfileService(
        timestampFactory: () => 'now',
        bootstrapUserProfile: ({
          required user,
          required authMethod,
          required isNewUserHint,
          required forceRefresh,
        }) async {},
        prepareProfileAccess: ({
          required user,
          required forceRefreshToken,
          required forceRefreshAppCheckToken,
        }) async {},
        writeUserDocument: ({required uid, required data}) async {
          userData = data;
        },
        businessProfileExists: (_) async => false,
        writeBusinessProfile: ({required uid, required data}) async {
          proData = data;
        },
      );

      await service.ensureEmailUserProfile(
        user: user,
        displayName: 'Sans email',
        isBusinessAccount: true,
      );

      expect(userData?.containsKey('email'), isFalse);
      expect(proData?.containsKey('contactEmail'), isFalse);
    });
  });
}

class _FakeUser implements User {
  _FakeUser({
    required this.uidValue,
    this.emailValue,
    this.emailVerifiedValue = false,
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
