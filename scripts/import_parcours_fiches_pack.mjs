import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

function usage() {
  console.log(
    'Usage: node scripts/import_parcours_fiches_pack.mjs --zip <pack.zip> [--project <firebase-project-id>] [--collection <collection>]'
  );
}

function readArgs(argv) {
  const args = {
    project: 'presto-app-74abe',
    collection: 'parcoursFiches',
  };
  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    const next = argv[index + 1];
    if (current === '--zip') {
      args.zip = next;
      index += 1;
    } else if (current === '--project') {
      args.project = next;
      index += 1;
    } else if (current === '--collection') {
      args.collection = next;
      index += 1;
    } else if (current === '--help' || current === '-h') {
      usage();
      process.exit(0);
    }
  }
  if (!args.zip) {
    usage();
    throw new Error('Argument requis manquant: --zip');
  }
  return args;
}

async function getFirebaseCliAccessToken() {
  const configPath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json'
  );
  if (!fs.existsSync(configPath)) {
    throw new Error(
      'Configuration Firebase CLI introuvable. Lancez `firebase login`.'
    );
  }

  // Ask the Firebase CLI to run a lightweight command so it refreshes its own token.
  try {
    execFileSync('firebase', ['--version'], { stdio: 'ignore' });
  } catch (_) {
    // best effort
  }

  const raw = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = raw.tokens?.access_token;
  if (!token) {
    throw new Error(
      'Access token Firebase CLI introuvable. Relancez `firebase login`.'
    );
  }
  return token;
}

function extractPack(zipPath) {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'parcours-fiches-'));
  execFileSync('unzip', ['-oq', zipPath, '-d', tempDir], { stdio: 'inherit' });
  const firebaseDir = findDirContaining(tempDir, 'firebase');
  const markdownDir = findDirContaining(tempDir, 'markdown');
  if (!firebaseDir) {
    throw new Error('Dossier firebase introuvable dans le pack');
  }
  const jsonFile = fs
    .readdirSync(firebaseDir)
    .find((entry) => entry.endsWith('.json') && !entry.endsWith('.jsonl'));
  if (!jsonFile) {
    throw new Error('Fichier JSON Firestore introuvable dans le pack');
  }
  return {
    jsonPath: path.join(firebaseDir, jsonFile),
    markdownDir,
  };
}

function loadMarkdownById(markdownDir) {
  const markdownById = new Map();
  if (!markdownDir || !fs.existsSync(markdownDir)) {
    return markdownById;
  }

  for (const entry of fs.readdirSync(markdownDir)) {
    if (!entry.endsWith('.md')) {
      continue;
    }
    const id = path.basename(entry, '.md');
    const markdown = fs.readFileSync(path.join(markdownDir, entry), 'utf8');
    markdownById.set(id, markdown);
  }

  return markdownById;
}

function findDirContaining(root, targetName) {
  const entries = fs.readdirSync(root, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(root, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === targetName) {
        return fullPath;
      }
      const nested = findDirContaining(fullPath, targetName);
      if (nested) {
        return nested;
      }
    }
  }
  return null;
}

function toFirestoreValue(value) {
  if (value === null) {
    return { nullValue: null };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map((item) => toFirestoreValue(item)) } };
  }
  switch (typeof value) {
    case 'string':
      return { stringValue: value };
    case 'boolean':
      return { booleanValue: value };
    case 'number':
      return Number.isInteger(value)
        ? { integerValue: String(value) }
        : { doubleValue: value };
    case 'object': {
      const fields = {};
      for (const [key, inner] of Object.entries(value)) {
        fields[key] = toFirestoreValue(inner);
      }
      return { mapValue: { fields } };
    }
    default:
      return { stringValue: String(value) };
  }
}

async function commitBatch({ accessToken, project, collection, batch }) {
  const writes = batch.map((fiche) => ({
    update: {
      name: `projects/${project}/databases/(default)/documents/${collection}/${fiche.id_fiche}`,
      fields: Object.fromEntries(
        Object.entries(fiche).map(([key, value]) => [key, toFirestoreValue(value)])
      ),
    },
  }));

  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents:commit`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ writes }),
    }
  );
  if (!response.ok) {
    throw new Error(`Commit Firestore ${response.status}: ${await response.text()}`);
  }
}

async function countDocuments({ accessToken, project, collection }) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${collection}?pageSize=300`,
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );
  if (!response.ok) {
    throw new Error(`Lecture Firestore ${response.status}: ${await response.text()}`);
  }
  const json = await response.json();
  return Array.isArray(json.documents) ? json.documents.length : 0;
}

async function main() {
  const args = readArgs(process.argv.slice(2));
  const { jsonPath, markdownDir } = extractPack(args.zip);
  const markdownById = loadMarkdownById(markdownDir);
  const fiches = JSON.parse(fs.readFileSync(jsonPath, 'utf8')).map((fiche) => {
    const markdown = markdownById.get(fiche.id_fiche);
    return markdown ? { ...fiche, markdown_content: markdown } : fiche;
  });
  const accessToken = await getFirebaseCliAccessToken();

  for (let index = 0; index < fiches.length; index += 200) {
    const batch = fiches.slice(index, index + 200);
    await commitBatch({
      accessToken,
      project: args.project,
      collection: args.collection,
      batch,
    });
  }

  const visibleCount = await countDocuments({
    accessToken,
    project: args.project,
    collection: args.collection,
  });

  const statuses = [...new Set(fiches.map((item) => item.statut_utilisateur))];
  console.log(
    JSON.stringify(
      {
        imported: fiches.length,
        visibleCount,
        collection: args.collection,
        project: args.project,
        statuses,
        source: args.zip,
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});