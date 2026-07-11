/// Règles pures de normalisation et de décision pour l'accès administrateur.
///
/// Cette policy ne dépend ni de Firebase ni de Flutter. Le resolver conserve
/// la responsabilité des lectures réseau et lui délègue les décisions locales.
class AdminAccessPolicy {
  const AdminAccessPolicy();

  List<String> normalizeRoles(Object? value) {
    final Iterable<Object?> rawValues;
    if (value is String) {
      rawValues = value.split(RegExp(r'[,\s]+'));
    } else if (value is Iterable) {
      rawValues = value.cast<Object?>();
    } else if (value is Map) {
      rawValues = value.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key);
    } else {
      return const <String>[];
    }

    return rawValues
        .map((entry) => entry?.toString().trim().toLowerCase() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  bool hasAdminAccess(
    Map<String, dynamic>? data, {
    required List<String> roles,
    required String? primaryRole,
  }) {
    final normalizedRoles = roles
        .map((role) => role.trim().toLowerCase())
        .where((role) => role.isNotEmpty);
    final normalizedPrimaryRole = normalizeText(primaryRole);

    if (normalizedRoles.contains('admin') ||
        normalizedRoles.contains('superadmin')) {
      return true;
    }
    if (normalizedPrimaryRole == 'admin' ||
        normalizedPrimaryRole == 'superadmin') {
      return true;
    }
    return data?['admin'] == true ||
        data?['isAdmin'] == true ||
        data?['superadmin'] == true ||
        data?['superAdmin'] == true;
  }

  String? firstNormalizedText(
    Map<String, dynamic>? data,
    Iterable<String> keys,
  ) {
    if (data == null) return null;
    for (final key in keys) {
      final value = normalizeText(data[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? normalizeText(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text.toLowerCase();
  }
}
