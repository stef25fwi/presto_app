import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/admin/messaging/admin_messaging_access_policy.dart';

void main() {
  const policy = AdminMessagingAccessPolicy();

  test('autorise superadmin et owner quelle que soit la source du rôle', () {
    expect(
      policy.canManageSettings(tokenRoles: const <String>[' SUPERADMIN ']),
      isTrue,
    );
    expect(
      policy.canManageSettings(profileRoles: const <String>['owner']),
      isTrue,
    );
    expect(policy.canManageSettings(tokenPrimaryRole: 'Owner'), isTrue);
    expect(policy.canManageSettings(profilePrimaryRole: 'superadmin'), isTrue);
  });

  test('refuse les rôles administratifs non autorisés aux paramètres', () {
    expect(
      policy.canManageSettings(
        tokenRoles: const <String>['admin'],
        profileRoles: const <String>['moderator', 'support'],
        tokenPrimaryRole: 'agent',
      ),
      isFalse,
    );
  });

  test('ignore les valeurs vides et normalise les doublons', () {
    expect(
      policy.canManageSettings(
        tokenRoles: const <String>['', ' owner ', 'OWNER'],
        profileRoles: const <String>['   '],
      ),
      isTrue,
    );
    expect(policy.canManageSettings(), isFalse);
  });
}
