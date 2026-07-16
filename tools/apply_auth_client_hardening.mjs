#!/usr/bin/env node

import fs from 'node:fs/promises';

const authPath = 'lib/services/auth_service.dart';
let auth = await fs.readFile(authPath, 'utf8');

function replaceOnce(content, before, after, label) {
  if (after && content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (!after && count === 0) return content;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

const injectedEmailVerificationCallable =
  "  Future<void> syncEmailVerifiedToFirestore() async {\n    _requireUser();\n    await _callFunction(\n      name: 'syncMyEmailVerification',\n      timeout: const Duration(seconds: 15),\n      parameters: const <String, dynamic>{},\n      area: 'auth',\n    );\n  }";

if (!auth.includes(injectedEmailVerificationCallable)) {
  auth = replaceOnce(
    auth,
    "  Future<void> syncEmailVerifiedToFirestore() async {\n    final user = _requireUser();\n\n    await _db.collection('users').doc(user.uid).set({\n      'email': user.email,\n      'emailVerified': user.emailVerified,\n      'updatedAt': FieldValue.serverTimestamp(),\n    }, SetOptions(merge: true));\n  }",
    "  Future<void> syncEmailVerifiedToFirestore() async {\n    _requireUser();\n    await callPrestoFunction<dynamic>(\n      functions: _functions,\n      name: 'syncMyEmailVerification',\n      timeout: const Duration(seconds: 15),\n      parameters: const <String, dynamic>{},\n      area: 'auth',\n    );\n  }",
    'email verification callable',
  );
}

auth = replaceOnce(
  auth,
  "      'emailVerified': user.emailVerified,\n",
  '',
  'remove client emailVerified profile write',
);

await fs.writeFile(authPath, auth, 'utf8');

const indexPath = 'functions/src/index.ts';
let index = await fs.readFile(indexPath, 'utf8');
index = replaceOnce(
  index,
  'export { requestAccountDeletion } from "./modules/auth/account_deletion";\n',
  'export { requestAccountDeletion } from "./modules/auth/account_deletion";\nexport { syncMyEmailVerification } from "./modules/auth/email_verification_sync";\n',
  'email verification export',
);
await fs.writeFile(indexPath, index, 'utf8');

console.log('auth client hardening patches: OK');
