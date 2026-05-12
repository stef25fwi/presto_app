import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/admin_access_state.dart';
import 'package:presto_app/services/user_profile_bootstrap_service.dart';

void main() {
  group('AdminAccessState consolidated access', () {
    test('prioritizes server confirmation over local evidence', () {
      final state = AdminAccessState.initial().copyWith(
        serverCheckSucceeded: true,
        serverIsAdmin: true,
        tokenHasAdmin: true,
        profileHasAdmin: true,
        adminDocHasAdmin: true,
      );

      expect(state.hasConfirmedAdminAccess, isTrue);
      expect(state.consolidatedSourceOfTruth, 'server');
    });

    test('falls back to token claims when server does not confirm admin', () {
      final state = AdminAccessState.initial().copyWith(
        serverCheckSucceeded: true,
        serverIsAdmin: false,
        tokenHasAdmin: true,
      );

      expect(state.hasConfirmedAdminAccess, isTrue);
      expect(state.consolidatedSourceOfTruth, 'token');
    });

    test('falls back to Firestore profile before admin document', () {
      final state = AdminAccessState.initial().copyWith(
        profileHasAdmin: true,
        adminDocHasAdmin: true,
      );

      expect(state.hasConfirmedAdminAccess, isTrue);
      expect(state.consolidatedSourceOfTruth, 'profile');
    });

    test('denies access only when no source confirms admin', () {
      final state = AdminAccessState.initial().copyWith(
        serverCheckSucceeded: true,
        serverIsAdmin: false,
      );

      expect(state.hasConfirmedAdminAccess, isFalse);
      expect(state.consolidatedSourceOfTruth, 'none');
    });

    test('server=true overrides local mismatch: effectiveIsAdmin is true', () {
      // Token has admin, Firestore profile does NOT (lag), but server confirmed.
      final state = AdminAccessState.initial().copyWith(
        serverCheckSucceeded: true,
        serverIsAdmin: true,
        tokenHasAdmin: true,
        profileHasAdmin: false,
        adminDocHasAdmin: false,
      );

      expect(state.hasConfirmedAdminAccess, isTrue);
      expect(state.consolidatedSourceOfTruth, 'server');
    });

    test('superadmin confirmed via server with partial profile', () {
      final state = AdminAccessState.initial().copyWith(
        isAuthenticated: true,
        serverCheckSucceeded: true,
        serverIsAdmin: true,
        serverSource: 'token',
        tokenHasAdmin: true,
        tokenRoles: ['user', 'admin', 'superadmin'],
        tokenPrimaryRole: 'superadmin',
        profileHasAdmin: true,
        profileRoles: ['user', 'admin', 'superadmin'],
        profilePrimaryRole: 'superadmin',
        effectiveIsAdmin: true,
        sourceOfTruth: 'server',
        lastStage: 'finished',
      );

      expect(state.effectiveIsAdmin, isTrue);
      expect(state.sourceOfTruth, 'server');
      expect(state.hasConfirmedAdminAccess, isTrue);
    });

    test('no server check but Firestore profile absent — token is fallback', () {
      final state = AdminAccessState.initial().copyWith(
        tokenHasAdmin: true,
        tokenRoles: ['admin'],
        profileHasAdmin: false,
        serverCheckSucceeded: false,
      );

      expect(state.hasConfirmedAdminAccess, isTrue);
      expect(state.consolidatedSourceOfTruth, 'token');
    });
  });

  group('UserProfileBootstrapService.normalizeUserProfileFromClaims', () {
    test('returns null when claims have no admin role', () {
      final result = UserProfileBootstrapService.normalizeUserProfileFromClaims(
        {'roles': ['user'], 'primaryRole': 'user'},
      );
      expect(result, isNull);
    });

    test('returns payload with admin fields when token has admin role', () {
      final result = UserProfileBootstrapService.normalizeUserProfileFromClaims(
        {
          'roles': ['user', 'admin'],
          'primaryRole': 'admin',
        },
      );
      expect(result, isNotNull);
      expect(result!['isAdmin'], isTrue);
      expect(result['admin'], isTrue);
      expect(result['roles'], containsAll(['user', 'admin']));
      expect(result['primaryRole'], 'admin');
    });

    test('sets primaryRole=superadmin when superadmin is in roles', () {
      final result = UserProfileBootstrapService.normalizeUserProfileFromClaims(
        {
          'roles': ['user', 'admin', 'superadmin'],
          'primaryRole': 'superadmin',
        },
      );
      expect(result, isNotNull);
      expect(result!['primaryRole'], 'superadmin');
    });

    test('returns null when claims are empty', () {
      final result = UserProfileBootstrapService.normalizeUserProfileFromClaims(
        <String, dynamic>{},
      );
      expect(result, isNull);
    });
  });

  group('AdminAccessState mismatch handling', () {
    test('server confirmation wins over token/profile mismatch', () {
      final state = AdminAccessState.initial().copyWith(
        serverCheckSucceeded: true,
        serverIsAdmin: true,
        tokenHasAdmin: true,
        profileHasAdmin: false,
      );

      expect(state.consolidatedSourceOfTruth, 'server');
      expect(state.hasConfirmedAdminAccess, isTrue);
      expect(state.effectiveIsAdmin, isFalse);

      final finalized = state.copyWith(
        effectiveIsAdmin: true,
        sourceOfTruth: state.consolidatedSourceOfTruth,
      );
      expect(finalized.effectiveIsAdmin, isTrue);
      expect(finalized.sourceOfTruth, 'server');
    });
  });

  group('normalizeUserProfileFromClaims', () {
    test('returns null for non-admin claims', () {
      final payload = UserProfileBootstrapService.normalizeUserProfileFromClaims(
        <String, dynamic>{
          'roles': <String>['user'],
          'primaryRole': 'user',
        },
      );

      expect(payload, isNull);
    });

    test('builds admin payload without user-profile fields override', () {
      final payload = UserProfileBootstrapService.normalizeUserProfileFromClaims(
        <String, dynamic>{
          'roles': <String>['user', 'admin', 'superadmin'],
          'primaryRole': 'superadmin',
        },
      );

      expect(payload, isNotNull);
      expect(payload!['roles'], <String>['user', 'admin', 'superadmin']);
      expect(payload['primaryRole'], 'superadmin');
      expect(payload['isAdmin'], isTrue);
      expect(payload['admin'], isTrue);
      expect(payload.containsKey('displayName'), isFalse);
      expect(payload.containsKey('photoURL'), isFalse);
      expect(payload.containsKey('phone'), isFalse);
      expect(payload.containsKey('address'), isFalse);
      expect(payload.containsKey('preferences'), isFalse);
    });
  });
}
