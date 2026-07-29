import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ON_CALL_PATTERN = /\bonCall\s*\(/g;
const SAFE_OPTION_PATTERN =
  /enforceAppCheck\s*:\s*(?:ENFORCE_APP_CHECK|true)\b/;
const FORBIDDEN_FALSE_PATTERN = /enforceAppCheck\s*:\s*false\b/;
const EXPLICIT_FALSE_OPTION_PATTERN = /enforceAppCheck\s*:\s*false\b/;
const OPTION_CONST_PATTERN =
  /const\s+([A-Z][A-Z0-9_]*)\s*=\s*\{([\s\S]*?)\}\s*(?:as const\s*)?;/g;

const LEGACY_EXCEPTIONS = new Map([
  [
    'functions/src/modules/messaging/callables.ts',
    {
      id: 'messaging-app-check-web-availability',
      reason:
        'Legacy messaging exception pending verified web reCAPTCHA/App Check rollout. Auth, participant checks, validation and rate limits remain mandatory.',
      reviewBy: '2026-08-31',
    },
  ],
]);

function normalizedPath(value) {
  return String(value ?? '').replaceAll('\\', '/');
}

function resolveLegacyException(filePath) {
  const normalized = normalizedPath(filePath);
  for (const [suffix, exception] of LEGACY_EXCEPTIONS) {
    if (normalized.endsWith(suffix)) return exception;
  }
  return null;
}

function collectSafeOptionConstants(source, allowExplicitFalse) {
  const definitions = new Map();
  for (const match of source.matchAll(OPTION_CONST_PATTERN)) {
    definitions.set(match[1], match[2]);
  }

  const safe = new Set();
  let changed = true;
  while (changed) {
    changed = false;
    for (const [name, body] of definitions) {
      if (safe.has(name)) continue;
      if (
        SAFE_OPTION_PATTERN.test(body) ||
        (allowExplicitFalse && EXPLICIT_FALSE_OPTION_PATTERN.test(body))
      ) {
        safe.add(name);
        changed = true;
        continue;
      }
      const spreadDependencies = [
        ...body.matchAll(/\.\.\.([A-Z][A-Z0-9_]*)/g),
      ].map((match) => match[1]);
      if (spreadDependencies.some((dependency) => safe.has(dependency))) {
        safe.add(name);
        changed = true;
      }
    }
  }
  return safe;
}

function hasSafeSpreadOption(objectSource, safeOptionConstants) {
  const spreadDependencies = [
    ...objectSource.matchAll(/\.\.\.([A-Z][A-Z0-9_]*)/g),
  ].map((match) => match[1]);
  return spreadDependencies.some((dependency) => safeOptionConstants.has(dependency));
}

function readFirstArgument(source, position) {
  const afterCall = source
    .slice(position)
    .replace(/^\bonCall\s*\(/, '')
    .trimStart();
  if (afterCall.startsWith('{')) {
    return { type: 'object', value: afterCall.slice(0, 1400) };
  }
  const identifier = afterCall.match(/^([A-Za-z_$][\w$]*)/);
  if (identifier) {
    return { type: 'identifier', value: identifier[1] };
  }
  return { type: 'unknown', value: afterCall.slice(0, 120) };
}

/**
 * Une exception App Check porte une date `reviewBy` : passé cette date, elle
 * cesse d'être une dérogation tracée et redevient une violation. Sans ce
 * contrôle, `reviewBy` n'est qu'un commentaire et l'exception survit
 * indéfiniment.
 */
export function isExpiredException(exception, now = new Date()) {
  if (!exception?.reviewBy) return false;
  const deadline = new Date(`${exception.reviewBy}T23:59:59.999Z`);
  if (Number.isNaN(deadline.getTime())) return true;
  return now.getTime() > deadline.getTime();
}

export function auditAppCheckSource(source, filePath = '<memory>', now = new Date()) {
  const violations = [];
  const exceptions = [];
  const callablePositions = [...source.matchAll(ON_CALL_PATTERN)].map(
    (match) => match.index ?? 0,
  );
  const legacyException = resolveLegacyException(filePath);
  const expired = legacyException != null && isExpiredException(legacyException, now);
  // Une exception périmée ne blanchit plus rien : les callables qu'elle
  // couvrait redeviennent des violations ordinaires.
  const activeException = expired ? null : legacyException;
  const safeOptionConstants = collectSafeOptionConstants(
    source,
    activeException != null,
  );

  if (FORBIDDEN_FALSE_PATTERN.test(source)) {
    if (expired) {
      violations.push({
        file: filePath,
        type: 'expired-exception',
        message:
          `App Check exception ${legacyException.id} expired on `
          + `${legacyException.reviewBy}: enforce App Check or extend the `
          + 'exception through an explicit review.',
      });
    } else if (legacyException) {
      exceptions.push({
        file: filePath,
        type: 'legacy-explicit-disable',
        ...legacyException,
      });
    } else {
      violations.push({
        file: filePath,
        type: 'explicit-disable',
        message: 'enforceAppCheck: false is forbidden in callable Functions.',
      });
    }
  }

  for (const position of callablePositions) {
    const firstArgument = readFirstArgument(source, position);
    const isSafeObject =
      firstArgument.type === 'object' &&
      (SAFE_OPTION_PATTERN.test(firstArgument.value) ||
        hasSafeSpreadOption(firstArgument.value, safeOptionConstants) ||
        (activeException &&
          EXPLICIT_FALSE_OPTION_PATTERN.test(firstArgument.value)));
    const isSafeIdentifier =
      firstArgument.type === 'identifier' &&
      safeOptionConstants.has(firstArgument.value);
    if (!isSafeObject && !isSafeIdentifier) {
      violations.push({
        file: filePath,
        type: 'missing-enforcement',
        message:
          'onCall must declare enforceAppCheck: ENFORCE_APP_CHECK or true in its options.',
      });
    }
  }

  return {
    callableCount: callablePositions.length,
    violations,
    exceptions,
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

export async function auditFunctionsAppCheck(root = 'functions/src', now = new Date()) {
  const files = await listTypeScriptFiles(root);
  const violations = [];
  const exceptions = [];
  let callableCount = 0;

  for (const file of files) {
    const source = await readFile(file, 'utf8');
    const result = auditAppCheckSource(source, file, now);
    callableCount += result.callableCount;
    violations.push(...result.violations);
    exceptions.push(...result.exceptions);
  }

  return {
    scannedFileCount: files.length,
    callableCount,
    violations,
    exceptions,
  };
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  const result = await auditFunctionsAppCheck(process.argv[2]);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (result.violations.length > 0) process.exitCode = 1;
}
