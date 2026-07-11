import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_access_policy.dart';

void main() {
  const policy = AdminAccessPolicy();

  group('normalizeRoles', () {
    test('normalise une chaîne séparée par espaces ou virgules', () {
      expect(policy.normalizeRoles(' User, ADMIN  superAdmin '), <String>[
        'user',
        'admin',
        'superadmin',
      ]);
    });

    test('normalise une liste et ignore les valeurs vides', () {
      expect(
        policy.normalizeRoles(<Object?>[' ADMIN ', '', null, 'user']),
        <String>['admin', 'user'],
      );
    });

    test('lit uniquement les clés actives d une map', () {
      expect(
        policy.normalizeRoles(<String, Object?>{
          'admin': true,
          'moderator': false,
          'SUPERADMIN': true,
        }),
        <String>['admin', 'superadmin'],
      );
    });

    test('retourne une liste vide pour une valeur non supportée', () {
      expect(policy.normalizeRoles(42), isEmpty);
      expect(policy.normalizeRoles(null), isEmpty);
    });
  });

  group('hasAdminAccess', () {
    test('autorise les rôles admin et superadmin', () {
      expect(
        policy.hasAdminAccess(
          null,
          roles: const <String>['user', 'ADMIN'],
          primaryRole: null,
        ),
        isTrue,
      );
      expect(
        policy.hasAdminAccess(
          null,
          roles: const <String>[],
          primaryRole: ' SuperAdmin ',
        ),
        isTrue,
      );
    });

    test('autorise les indicateurs historiques explicites', () {
      for (final key in <String>[
        'admin',
        'isAdmin',
        'superadmin',
        'superAdmin',
      ]) {
        expect(
          policy.hasAdminAccess(
            <String, dynamic>{key: true},
            roles: const <String>[],
            primaryRole: null,
          ),
          isTrue,
          reason: key,
        );
      }
    });

    test('refuse un utilisateur sans preuve admin', () {
      expect(
        policy.hasAdminAccess(
          <String, dynamic>{'admin': false},
          roles: const <String>['user', 'moderator'],
          primaryRole: 'user',
        ),
        isFalse,
      );
    });
  });

  test('firstNormalizedText retourne la première valeur exploitable', () {
    expect(
      policy.firstNormalizedText(
        <String, dynamic>{
          'primaryRole': '   ',
          'role': ' ADMIN ',
          'adminRole': 'superadmin',
        },
        const <String>['primaryRole', 'role', 'adminRole'],
      ),
      'admin',
    );
    expect(policy.firstNormalizedText(null, const <String>['role']), isNull);
  });
}
