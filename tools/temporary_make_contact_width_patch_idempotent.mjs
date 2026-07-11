import { readFile, writeFile } from 'node:fs/promises';

const path = 'tools/apply_validation_round2_fixes.mjs';
let source = await readFile(path, 'utf8');
const before = `  content = replaceOnce(\n    content,\n    contactBefore,\n    contactAfter,\n    'task contact chip max width',\n  );`;
const after = `  if (!content.includes('constraints: const BoxConstraints(maxWidth: 280)')) {\n    content = replaceOnce(\n      content,\n      contactBefore,\n      contactAfter,\n      'task contact chip max width',\n    );\n  }`;
if (!source.includes(before)) {
  throw new Error('contact width generator block not found');
}
source = source.replace(before, after);
await writeFile(path, source, 'utf8');
console.log('contact width generator is now format-independent');
