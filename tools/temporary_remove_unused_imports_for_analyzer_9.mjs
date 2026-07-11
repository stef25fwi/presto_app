import { readFile, writeFile } from 'node:fs/promises';

const removals = [
  ['lib/admin/messaging/admin_conversation_detail_page.dart', "import 'package:cloud_firestore/cloud_firestore.dart';\n"],
  ['lib/admin/messaging/admin_messaging_center_page.dart', "import 'models/admin_audit_log_model.dart';\n"],
  ['lib/admin/messaging/admin_messaging_center_page.dart', "import 'services/admin_messaging_audit_service.dart';\n"],
  ['lib/pages/account/mes_projets_fiche_page.dart', "import '../toolbox_je_me_lance_page.dart';\n"],
  ['lib/pages/fiche_pro_page.dart', "import 'dart:typed_data';\n"],
];

for (const [path, importLine] of removals) {
  const source = await readFile(path, 'utf8');
  if (!source.includes(importLine)) continue;
  await writeFile(path, source.replace(importLine, ''), 'utf8');
}

console.log('removed 5 unused imports');
