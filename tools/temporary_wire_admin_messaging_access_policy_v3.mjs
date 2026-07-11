import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/admin/messaging/admin_messaging_center_page.dart';
let source = await readFile(path, 'utf8');

const importLine = "import 'admin_messaging_access_policy.dart';";
const importAnchor = "import 'admin_attachments_page.dart';";
if (!source.includes(importLine)) {
  if (!source.includes(importAnchor)) throw new Error('import anchor not found');
  source = source.replace(importAnchor, `${importLine}\n${importAnchor}`);
}

const oldBlock = `  bool get _canManageSettings {
    final state = widget.accessState;
    if (state == null) return false;
    final roles = <String>{
      ...state.tokenRoles.map((item) => item.trim().toLowerCase()),
      ...state.profileRoles.map((item) => item.trim().toLowerCase()),
      (state.tokenPrimaryRole ?? '').trim().toLowerCase(),
      (state.profilePrimaryRole ?? '').trim().toLowerCase(),
    }..removeWhere((item) => item.isEmpty);
    return roles.contains('superadmin') || roles.contains('owner');
  }`;

const newBlock = `  static const AdminMessagingAccessPolicy _accessPolicy =
      AdminMessagingAccessPolicy();

  bool get _canManageSettings {
    final state = widget.accessState;
    if (state == null) return false;
    return _accessPolicy.canManageSettings(
      tokenRoles: state.tokenRoles,
      profileRoles: state.profileRoles,
      tokenPrimaryRole: state.tokenPrimaryRole,
      profilePrimaryRole: state.profilePrimaryRole,
    );
  }`;

if (!source.includes(newBlock)) {
  if (!source.includes(oldBlock)) throw new Error('access getter anchor not found');
  source = source.replace(oldBlock, newBlock);
}

await writeFile(path, source, 'utf8');
console.log('admin messaging access policy wired');
