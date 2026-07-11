import { readFile, writeFile } from 'node:fs/promises';

const files = [
  {
    path: 'functions/src/modules/auth/account_deletion.ts',
    replacements: [
      [
        'import { PROJECT_REGION, STRIPE_SECRET_KEY } from "../../config/env";',
        'import { ENFORCE_APP_CHECK, PROJECT_REGION, STRIPE_SECRET_KEY } from "../../config/env";',
      ],
      ['enforceAppCheck: true,', 'enforceAppCheck: ENFORCE_APP_CHECK,'],
    ],
  },
  {
    path: 'functions/src/modules/messaging/callables.ts',
    replacements: [
      [
        'import { PROJECT_REGION } from "../../config/env";',
        'import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";',
      ],
      ['enforceAppCheck: false,', 'enforceAppCheck: ENFORCE_APP_CHECK,'],
    ],
  },
  {
    path: 'functions/src/modules/monitoring/callables.ts',
    replacements: [
      [
        'import { PROJECT_REGION } from "../../config/env";',
        'import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../config/env";',
      ],
      ['enforceAppCheck: true,', 'enforceAppCheck: ENFORCE_APP_CHECK,'],
    ],
  },
  {
    path: 'functions/src/modules/pro/preVerifySiret.ts',
    replacements: [
      [
        'import { HttpsError, onCall } from "firebase-functions/v2/https";\n',
        'import { HttpsError, onCall } from "firebase-functions/v2/https";\n\nimport { ENFORCE_APP_CHECK } from "../../config/env";\n',
      ],
      ['enforceAppCheck: true,', 'enforceAppCheck: ENFORCE_APP_CHECK,'],
    ],
  },
  {
    path: 'functions/src/modules/pro/verifySiret.ts',
    replacements: [
      [
        'import * as https from "https";\n',
        'import * as https from "https";\n\nimport {ENFORCE_APP_CHECK} from "../../config/env";\n',
      ],
      ['enforceAppCheck: true,', 'enforceAppCheck: ENFORCE_APP_CHECK,'],
    ],
  },
];

for (const file of files) {
  let source = await readFile(file.path, 'utf8');
  for (const [before, after] of file.replacements) {
    if (source.includes(after)) continue;
    if (!source.includes(before)) {
      throw new Error(`replacement anchor not found in ${file.path}: ${before}`);
    }
    source = source.replace(before, after);
  }
  await writeFile(file.path, source, 'utf8');
}

console.log('central App Check policy applied to callable modules');
