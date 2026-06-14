import fs from "node:fs/promises";
import path from "node:path";

import admin from "firebase-admin";

export type ScriptOptions = {
  dryRun: boolean;
  projectId: string;
  outPath?: string;
};

export function parseCommonArgs(argv: string[]): ScriptOptions {
  const options: ScriptOptions = {
    dryRun: true,
    projectId: String(process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "").trim(),
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index] || "";
    if (arg === "--apply") {
      options.dryRun = false;
      continue;
    }
    if (arg === "--dry-run") {
      options.dryRun = true;
      continue;
    }
    if (arg.startsWith("--project=")) {
      options.projectId = arg.slice("--project=".length).trim();
      continue;
    }
    if (arg.startsWith("--out=")) {
      options.outPath = arg.slice("--out=".length).trim();
    }
  }

  return options;
}

export function initAdmin(projectId: string): FirebaseFirestore.Firestore {
  if (!admin.apps.length) {
    admin.initializeApp(projectId ? { projectId } : {});
  }

  return admin.firestore();
}

export function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

export function slugify(value: unknown): string {
  return normalizeString(value)
    .toLowerCase()
    // Ligatures non d\u00e9composables par NFD \u2014 \u00e0 remplacer avant normalisation
    // pour rester coh\u00e9rent avec offerSlugify() c\u00f4t\u00e9 Dart.
    .replace(/\u0153/g, "oe")
    .replace(/\u00e6/g, "ae")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export async function writeJsonReport(report: unknown, outPath?: string): Promise<void> {
  const serialized = `${JSON.stringify(report, null, 2)}\n`;
  if (!outPath) {
    process.stdout.write(serialized);
    return;
  }

  const resolved = path.resolve(outPath);
  await fs.mkdir(path.dirname(resolved), { recursive: true });
  await fs.writeFile(resolved, serialized, "utf8");
  process.stdout.write(`${resolved}\n`);
}

export function isActiveLegacyOffer(data: Record<string, unknown>): boolean {
  const status = normalizeString(data.status).toLowerCase();
  return status === "active" || status === "published" || data.isActive === true || data.isPublished === true;
}

export function pickOwnerId(data: Record<string, unknown>): string {
  return normalizeString(data.ownerId || data.userId || data.uid || data.owner_id);
}

export function pickTimestamp(value: unknown): FirebaseFirestore.Timestamp | null {
  return value instanceof admin.firestore.Timestamp ? value : null;
}

export async function commitBatch(
  batch: FirebaseFirestore.WriteBatch,
  count: number,
): Promise<FirebaseFirestore.WriteBatch> {
  if (count > 0) {
    await batch.commit();
  }
  return admin.firestore().batch();
}