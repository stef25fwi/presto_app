import { readFile, writeFile } from 'node:fs/promises';

// Second push: the temporary workflow already exists on this branch.
const path = 'tools/apply_validation_round2_fixes.mjs';
let source = await readFile(path, 'utf8');
const before = `  content = replaceOnce(
    content,
    contactBefore,
    contactAfter,
    'task contact chip max width',
  );`;
const after = `  if (!content.includes('constraints: const BoxConstraints(maxWidth: 280)')) {
    content = replaceOnce(
      content,
      contactBefore,
      contactAfter,
      'task contact chip max width',
    );
  }`;
if (!source.includes(before)) {
  throw new Error('contact width generator block not found');
}
source = source.replace(before, after);
await writeFile(path, source, 'utf8');
console.log('contact width generator is now format-independent');
