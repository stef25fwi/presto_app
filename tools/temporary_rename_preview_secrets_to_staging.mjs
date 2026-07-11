import { readFile, writeFile } from 'node:fs/promises';

const path = '.github/workflows/pr-validation.yml';
let source = await readFile(path, 'utf8');

const replacements = [
  [
    '          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}\n          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}',
    '          FIREBASE_TOKEN: ${{ secrets.FIREBASE_STAGING_TOKEN }}\n          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_STAGING_PROJECT_ID }}',
  ],
  [
    "echo 'Firebase preview skipped: FIREBASE_TOKEN is missing.'",
    "echo 'Firebase preview skipped: FIREBASE_STAGING_TOKEN is missing.'",
  ],
];

for (const [before, after] of replacements) {
  if (!source.includes(before)) {
    if (source.includes(after)) continue;
    throw new Error(`preview staging secret anchor not found: ${before}`);
  }
  source = source.split(before).join(after);
}

await writeFile(path, source, 'utf8');
console.log('preview secrets renamed to staging-specific names');
