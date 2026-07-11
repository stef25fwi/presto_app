import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ON_CALL_PATTERN = /\bonCall\s*\(/g;
const REQUIRED_OPTION_PATTERN = /enforceAppCheck\s*:\s*ENFORCE_APP_CHECK/;
const FORBIDDEN_FALSE_PATTERN = /enforceAppCheck\s*:\s*false\b/;

export function auditAppCheckSource(source, filePath = '<memory>') {
  const violations = [];
  const callablePositions = [...source.matchAll(ON_CALL_PATTERN)].map(
    (match) => match.index ?? 0,
  );

  if (FORBIDDEN_FALSE_PATTERN.test(source)) {
    violations.push({
      file: filePath,
      type: 'explicit-disable',
      message: 'enforceAppCheck: false is forbidden in callable Functions.',
    });
  }

  for (const position of callablePositions) {
    const snippet = source.slice(position, position + 1400);
    if (!REQUIRED_OPTION_PATTERN.test(snippet)) {
      violations.push({
        file: filePath,
        type: 'missing-enforcement',
        message:
          'onCall must declare enforceAppCheck: ENFORCE_APP_CHECK in its options.',
      });
    }
  }

  return {
    callableCount: callablePositions.length,
    violations,
  };
}

async function listTypeScriptFiles(root) {
  const entries = await readdir(root, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const absolute = path.join(root, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listTypeScriptFiles(absolute)));
      continue;
    }
    if (
      entry.isFile() &&
      entry.name.endsWith('.ts') &&
      !entry.name.endsWith('.test.ts') &&
      !entry.name.endsWith('.spec.ts')
    ) {
      files.push(absolute);
    }
  }
  return files;
}

export async function auditFunctionsAppCheck(root = 'functions/src') {
  const files = await listTypeScriptFiles(root);
  const violations = [];
  let callableCount = 0;

  for (const file of files) {
    const source = await readFile(file, 'utf8');
    const result = auditAppCheckSource(source, file);
    callableCount += result.callableCount;
    violations.push(...result.violations);
  }

  return {
    scannedFileCount: files.length,
    callableCount,
    violations,
  };
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  const result = await auditFunctionsAppCheck(process.argv[2]);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (result.violations.length > 0) process.exitCode = 1;
}
