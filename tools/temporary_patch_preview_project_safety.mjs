import { readFile, writeFile } from 'node:fs/promises';

const path = '.github/workflows/pr-validation.yml';
let source = await readFile(path, 'utf8');

const oldBlock = `      - name: Check preview credentials
        id: preview_config
        env:
          FIREBASE_TOKEN: \${{ secrets.FIREBASE_TOKEN }}
          FIREBASE_PROJECT_ID: \${{ secrets.FIREBASE_PROJECT_ID }}
        run: |
          if [ -n "$FIREBASE_TOKEN" ] && [ -n "$FIREBASE_PROJECT_ID" ]; then
            echo 'enabled=true' >> "$GITHUB_OUTPUT"
          else
            echo 'enabled=false' >> "$GITHUB_OUTPUT"
            echo 'Firebase preview skipped: FIREBASE_TOKEN or FIREBASE_PROJECT_ID is missing.' >> "$GITHUB_STEP_SUMMARY"
          fi`;

const newBlock = `      - name: Check preview credentials and project safety
        id: preview_config
        env:
          FIREBASE_TOKEN: \${{ secrets.FIREBASE_TOKEN }}
          FIREBASE_PROJECT_ID: \${{ secrets.FIREBASE_PROJECT_ID }}
        run: |
          set -euo pipefail
          if [ -z "$FIREBASE_TOKEN" ]; then
            echo 'enabled=false' >> "$GITHUB_OUTPUT"
            echo 'Firebase preview skipped: FIREBASE_TOKEN is missing.' >> "$GITHUB_STEP_SUMMARY"
            exit 0
          fi

          result=$(node tools/quality/check_firebase_preview_project.mjs)
          enabled=$(node -e "const value=JSON.parse(process.argv[1]); process.stdout.write(String(value.enabled));" "$result")
          message=$(node -e "const value=JSON.parse(process.argv[1]); process.stdout.write(value.message);" "$result")
          echo "$message" >> "$GITHUB_STEP_SUMMARY"
          echo "enabled=$enabled" >> "$GITHUB_OUTPUT"`;

if (source.includes(newBlock)) {
  console.log('preview safety already applied');
  process.exit(0);
}
if (!source.includes(oldBlock)) {
  throw new Error('preview credential block not found');
}
source = source.replace(oldBlock, newBlock);
await writeFile(path, source, 'utf8');
console.log('preview project safety applied');
