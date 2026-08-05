import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const functionsDir = path.resolve(process.cwd(), "functions");
const sourceDir = path.join(functionsDir, "src");
const compatFile = path.join(sourceDir, "core", "firebase_admin_compat.ts");

async function collectTypeScriptFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await collectTypeScriptFiles(absolute)));
    } else if (entry.isFile() && entry.name.endsWith(".ts")) {
      files.push(absolute);
    }
  }

  return files;
}

function compatSpecifier(file) {
  const withoutExtension = compatFile.replace(/\.ts$/u, "");
  let relative = path.relative(path.dirname(file), withoutExtension);
  relative = relative.split(path.sep).join("/");
  return relative.startsWith(".") ? relative : `./${relative}`;
}

function migrateSource(source, specifier) {
  return source
    .replace(
      /import\s+admin\s+from\s+["']firebase-admin["'];?/gu,
      `import admin from "${specifier}";`,
    )
    .replace(
      /import\s+\*\s+as\s+admin\s+from\s+["']firebase-admin["'];?/gu,
      `import admin from "${specifier}";`,
    )
    .replace(
      /const\s+admin\s*=\s*require\(["']firebase-admin["']\);?/gu,
      `import admin from "${specifier}";`,
    );
}

const files = (await collectTypeScriptFiles(sourceDir)).filter(
  (file) => file !== compatFile,
);
let changedFiles = 0;
const unresolved = [];

for (const file of files) {
  const source = await readFile(file, "utf8");
  const migrated = migrateSource(source, compatSpecifier(file));

  if (/from\s+["']firebase-admin["']/u.test(migrated)) {
    unresolved.push(path.relative(functionsDir, file));
  }

  if (migrated !== source) {
    await writeFile(file, migrated, "utf8");
    changedFiles += 1;
  }
}

if (unresolved.length > 0) {
  console.error("Unsupported firebase-admin root imports remain:");
  for (const file of unresolved) {
    console.error(`- ${file}`);
  }
  process.exitCode = 1;
} else {
  console.log(`Migrated ${changedFiles} TypeScript file(s) to the v14 compatibility layer.`);
}
