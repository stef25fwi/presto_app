import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/admin_access_state.dart';

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
  });
}
