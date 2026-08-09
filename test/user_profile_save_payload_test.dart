import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/user_profile_save_payload.dart';

void main() {
  group('UserProfileSavePayload', () {
    test('calcule une complétude strictement positive avec champs remplis', () {
      expect(
        UserProfileSavePayload.calculateCompleteness(
          displayName: 'Stephane S',
          city: 'Baie-Mahault',
          phone: '+590690000000',
        ),
        greaterThan(0),
      );
    });

    test('écrit les champs profil attendus sans champs admin protégés', () {
      final payload = UserProfileSavePayload.build(
        uid: 'uid-123',
        email: 'USER@EXAMPLE.COM ',
        displayName: ' Stephane S ',
        accountType: 'Particulier',
        phone: '+590690000000',
        city: 'Baie-Mahault (97122)',
        selectedFavoriteCategories: const <String>['Jardinage'],
        selectedFavoriteSubcategories: const <String>['Jardinage — Tonte'],
      );

      const allowedKeys = <String>{
        'uid',
        'email',
        'displayName',
        'pseudo',
        'phone',
        'phoneCountryCode',
        'city',
        'ville',
        'commune',
        'locality',
        'postalCode',
        'codePostal',
        'zipCode',
        'cp',
        'accountType',
        'selectedFavoriteCategories',
        'selectedFavoriteSubcategories',
        'selectedFavoriteDepartements',
        'profileCompleted',
        'profileCompleteness',
        'profileUpdatedAt',
        'updatedAt',
      };

      expect(payload['uid'], 'uid-123');
      expect(payload['email'], 'user@example.com');
      expect(payload['displayName'], 'Stephane S');
      expect(payload['pseudo'], 'Stephane S');
      expect(payload['accountType'], 'Particulier');
      expect(payload['phone'], '+590690000000');
      expect(payload['phoneCountryCode'], '+590');
      expect(payload['city'], 'Baie-Mahault');
      expect(payload['ville'], 'Baie-Mahault');
      expect(payload['commune'], 'Baie-Mahault');
      expect(payload['locality'], 'Baie-Mahault');
      expect(payload['postalCode'], '97122');
      expect(payload['codePostal'], '97122');
      expect(payload['zipCode'], '97122');
      expect(payload['cp'], '97122');
      expect(
          payload['selectedFavoriteCategories'], const <String>['Jardinage']);
      expect(
        payload['selectedFavoriteSubcategories'],
        const <String>['Jardinage — Tonte'],
      );
      expect(payload['profileCompleted'], isTrue);
      expect(payload['profileCompleteness'], greaterThan(0));
      expect(payload, contains('profileUpdatedAt'));
      expect(payload, contains('updatedAt'));
      expect(payload.keys.toSet().difference(allowedKeys), isEmpty);

      for (final subscriptionKey in <String>[
        'subscriptionPlan',
        'subscriptionStatus',
        'subscriptionExpiresAt',
        'phoneVerified',
        'proVerified',
      ]) {
        expect(
          payload.containsKey(subscriptionKey),
          isFalse,
          reason:
              'La sauvegarde profil ne doit pas réinitialiser les champs abonnement.',
        );
      }

      for (final protectedKey in <String>[
        'admin',
        'superadmin',
        'isAdmin',
        'roles',
        'role',
        'primaryRole',
        'moderator',
        'marketplaceAccess',
        'status',
        'disabled',
        'createdAt',
        'last_login_ip',
        'login_signatures',
        'last_login_signature',
      ]) {
        expect(payload.containsKey(protectedKey), isFalse);
      }
    });
  });
}
