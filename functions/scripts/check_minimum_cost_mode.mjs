import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = path.resolve(import.meta.dirname, "..");

async function sourceFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...await sourceFiles(absolute));
    } else if (/\.(?:ts|js)$/.test(entry.name) && !entry.name.endsWith(".test.ts")) {
      files.push(absolute);
    }
  }
  return files;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const packageJson = JSON.parse(await readFile(path.join(root, "package.json"), "utf8"));
assert(
  !packageJson.dependencies?.["@google-cloud/vertexai"],
  "Unused Vertex AI dependency must stay removed.",
);

const runtimeFiles = [
  path.join(root, "index.js"),
  ...await sourceFiles(path.join(root, "src")),
];
const runtimeSources = await Promise.all(
  runtimeFiles.map(async (file) => ({
    file,
    source: await readFile(file, "utf8"),
  })),
);

const warmInstances = runtimeSources.filter(({ source }) =>
  /minInstances\s*:\s*[1-9]/.test(source)
);
assert(
  warmInstances.length === 0,
  `Warm instances found in: ${warmInstances.map(({ file }) => file).join(", ")}`,
);

const legacy = await readFile(path.join(root, "index.js"), "utf8");
assert(
  legacy.includes("https://data.geopf.fr/geocodage"),
  "Géoplateforme address lookup is missing.",
);
assert(
  !legacy.includes("maps.googleapis.com/maps/api/place"),
  "Legacy Google Places endpoint must not be restored.",
);

const exportsSource = await readFile(path.join(root, "src/index.ts"), "utf8");
assert(
  exportsSource.includes("runCostOptimizedMinuteTasks") &&
    exportsSource.includes("runCostOptimizedQuarterHourTasks"),
  "Cost-optimized scheduler exports are missing.",
);

const videoMaker = await readFile(
  path.join(root, "src/modules/admin/videomaker.ts"),
  "utf8",
);
assert(
  videoMaker.includes("COST_POLICY.veoGenerationEnabled") &&
    videoMaker.includes("COST_POLICY.veoMonthlyGenerationLimit"),
  "Veo must remain disabled and quota-protected by default.",
);

console.log("Minimum-cost runtime audit passed.");
