import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/services/admin_access_resolver.dart';
let source = await readFile(path, 'utf8');

const replaceOnce = (before, after, label) => {
  if (!source.includes(before)) {
    throw new Error(`Bloc introuvable: ${label}`);
  }
  source = source.replace(before, after);
};

replaceOnce(
  "import '../models/admin_access_state.dart';\n",
  "import '../models/admin_access_state.dart';\nimport 'admin_access_policy.dart';\n",
  'policy import',
);

replaceOnce(
  "  static const String _adminAccessCallableName = 'getMyAdminAccessStatus';\n",
  "  static const String _adminAccessCallableName = 'getMyAdminAccessStatus';\n  static const AdminAccessPolicy _accessPolicy = AdminAccessPolicy();\n",
  'policy field',
);

replaceOnce(
  `  List<String> _rolesFromValue(dynamic value) {\n    final Iterable<dynamic> rawValues;\n    if (value is String) {\n      rawValues = value.split(RegExp(r'[,\\s]+'));\n    } else if (value is Iterable) {\n      rawValues = value;\n    } else if (value is Map) {\n      rawValues = value.entries\n          .where((entry) => entry.value == true)\n          .map((entry) => entry.key);\n    } else {\n      return const <String>[];\n    }\n\n    return rawValues\n        .map((entry) => entry.toString().trim().toLowerCase())\n        .where((entry) => entry.isNotEmpty)\n        .toList(growable: false);\n  }`,
  `  List<String> _rolesFromValue(dynamic value) =>\n      _accessPolicy.normalizeRoles(value);`,
  'roles normalizer',
);

replaceOnce(
  `  bool _hasAdminAccess(\n    Map<String, dynamic>? data, {\n    required List<String> roles,\n    required String? primaryRole,\n  }) {\n    if (roles.contains('admin') || roles.contains('superadmin')) {\n      return true;\n    }\n    if (primaryRole == 'admin' || primaryRole == 'superadmin') {\n      return true;\n    }\n    return data?['admin'] == true ||\n        data?['isAdmin'] == true ||\n        data?['superadmin'] == true ||\n        data?['superAdmin'] == true;\n  }`,
  `  bool _hasAdminAccess(\n    Map<String, dynamic>? data, {\n    required List<String> roles,\n    required String? primaryRole,\n  }) =>\n      _accessPolicy.hasAdminAccess(\n        data,\n        roles: roles,\n        primaryRole: primaryRole,\n      );`,
  'admin access decision',
);

replaceOnce(
  `  String? _firstNormalizedText(\n    Map<String, dynamic>? data,\n    List<String> keys,\n  ) {\n    if (data == null) return null;\n    for (final key in keys) {\n      final value = _normalizedText(data[key]);\n      if (value != null) return value;\n    }\n    return null;\n  }\n\n  String? _normalizedText(dynamic value) {\n    final text = value?.toString().trim();\n    if (text == null || text.isEmpty) {\n      return null;\n    }\n    return text.toLowerCase();\n  }`,
  `  String? _firstNormalizedText(\n    Map<String, dynamic>? data,\n    List<String> keys,\n  ) =>\n      _accessPolicy.firstNormalizedText(data, keys);`,
  'normalized text helpers',
);

await writeFile(path, source, 'utf8');
console.log('AdminAccessResolver utilise désormais AdminAccessPolicy.');
