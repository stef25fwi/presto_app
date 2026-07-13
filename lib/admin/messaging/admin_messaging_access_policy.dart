class AdminMessagingAccessPolicy {
  const AdminMessagingAccessPolicy();

  bool canManageSettings({
    Iterable<String> tokenRoles = const <String>[],
    Iterable<String> profileRoles = const <String>[],
    String? tokenPrimaryRole,
    String? profilePrimaryRole,
  }) {
    final roles = <String>{
      ...tokenRoles.map(_normalizeRole),
      ...profileRoles.map(_normalizeRole),
      _normalizeRole(tokenPrimaryRole),
      _normalizeRole(profilePrimaryRole),
    }..removeWhere((role) => role.isEmpty);

    return roles.contains('superadmin') || roles.contains('owner');
  }

  String _normalizeRole(Object? value) {
    return (value ?? '').toString().trim().toLowerCase();
  }
}
