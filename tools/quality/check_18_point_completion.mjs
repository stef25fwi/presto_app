#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";

const ALLOWED_STATUSES = new Set(["blocked", "active", "verified"]);

function parseArgs(argv) {
  const options = {
    registry: "quality/18-point-completion.json",
    reportPath: null,
    json: false,
    requireComplete: false,
    runCommands: false,
    promote: false,
    registryOutput: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--registry":
        options.registry = argv[++index];
        break;
      case "--report-path":
        options.reportPath = argv[++index];
        break;
      case "--registry-output":
        options.registryOutput = argv[++index];
        break;
      case "--json":
        options.json = true;
        break;
      case "--require-complete":
        options.requireComplete = true;
        break;
      case "--run-commands":
        options.runCommands = true;
        break;
      case "--promote":
        options.promote = true;
        options.requireComplete = true;
        options.runCommands = true;
        break;
      default:
        throw new Error(`Argument inconnu : ${arg}`);
    }
  }

  if (!options.registry) {
    throw new Error("--registry nécessite un chemin.");
  }
  return options;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function validateRegistry(registry) {
  const errors = [];
  const points = registry?.points;

  if (!Array.isArray(points) || points.length !== 18) {
    errors.push("Le registre doit contenir exactement 18 points.");
    return { errors, activePoint: null, allVerified: false };
  }

  for (let index = 0; index < points.length; index += 1) {
    const point = points[index];
    const expectedId = index + 1;
    if (point.id !== expectedId) {
      errors.push(`Le point à l’index ${index} doit avoir l’id ${expectedId}.`);
    }
    if (!point.name || typeof point.name !== "string") {
      errors.push(`Le point ${expectedId} doit avoir un nom.`);
    }
    if (!ALLOWED_STATUSES.has(point.status)) {
      errors.push(
        `Le point ${expectedId} utilise le statut invalide « ${point.status} ».`,
      );
    }
    if (!Array.isArray(point.doneWhen) || point.doneWhen.length === 0) {
      errors.push(`Le point ${expectedId} doit définir doneWhen.`);
    }
    if (!Array.isArray(point.requiredFiles)) {
      errors.push(`Le point ${expectedId} doit définir requiredFiles.`);
    }
    if (!Array.isArray(point.controlFiles)) {
      errors.push(`Le point ${expectedId} doit définir controlFiles.`);
    }
    if (!Array.isArray(point.validationCommands)) {
      errors.push(`Le point ${expectedId} doit définir validationCommands.`);
    }
  }

  const activePoints = points.filter((point) => point.status === "active");
  const allVerified = points.every((point) => point.status === "verified");

  if (allVerified) {
    if (activePoints.length !== 0) {
      errors.push("Aucun point ne doit rester actif lorsque les 18 sont verified.");
    }
    return { errors, activePoint: null, allVerified: true };
  }

  if (activePoints.length !== 1) {
    errors.push(
      `Un seul point doit être actif ; valeur constatée : ${activePoints.length}.`,
    );
    return { errors, activePoint: activePoints[0] ?? null, allVerified: false };
  }

  const activePoint = activePoints[0];
  for (const point of points) {
    if (point.id < activePoint.id && point.status !== "verified") {
      errors.push(
        `Le point ${point.id} précède le point actif ${activePoint.id} mais n’est pas verified.`,
      );
    }
    if (point.id > activePoint.id && point.status !== "blocked") {
      errors.push(
        `Le point ${point.id} doit rester blocked tant que le point ${activePoint.id} n’est pas verified.`,
      );
    }
  }

  return { errors, activePoint, allVerified: false };
}

function evaluateControlFile(root, definition) {
  const absolutePath = resolve(root, definition.path);
  const result = {
    path: definition.path,
    exists: existsSync(absolutePath),
    rootStatus: null,
    controlsTotal: 0,
    controlsAccepted: 0,
    errors: [],
  };

  if (!result.exists) {
    result.errors.push("fichier absent");
    return result;
  }

  let data;
  try {
    data = readJson(absolutePath);
  } catch (error) {
    result.errors.push(`JSON invalide : ${error.message}`);
    return result;
  }

  result.rootStatus = data.status ?? null;
  const acceptedRootStatuses = definition.acceptedRootStatuses;
  if (
    Array.isArray(acceptedRootStatuses) &&
    !acceptedRootStatuses.includes(result.rootStatus)
  ) {
    result.errors.push(
      `statut racine « ${result.rootStatus} » non accepté (${acceptedRootStatuses.join(", ")})`,
    );
  }

  const controls = Array.isArray(data.controls) ? data.controls : [];
  if (controls.length === 0) {
    result.errors.push("aucun contrôle déclaré");
    return result;
  }

  const acceptedStatuses = new Set(definition.acceptedStatuses ?? ["verified"]);
  const requiredControls = controls.filter((control) => control.required !== false);
  result.controlsTotal = requiredControls.length;

  for (const control of requiredControls) {
    if (acceptedStatuses.has(control.status)) {
      result.controlsAccepted += 1;
    } else {
      result.errors.push(
        `${control.id ?? control.title ?? "contrôle sans id"}: ${control.status ?? "sans statut"}`,
      );
    }
  }

  return result;
}

function runValidationCommands(commands, root) {
  const results = [];
  for (const command of commands) {
    process.stderr.write(`\n[18/18] Exécution : ${command}\n`);
    const execution = spawnSync(command, {
      cwd: root,
      shell: true,
      stdio: "inherit",
      env: process.env,
    });
    const status = execution.status ?? 1;
    results.push({ command, status, passed: status === 0 });
    if (status !== 0) break;
  }
  return results;
}

function evaluatePoint(point, root, { runCommands = false } = {}) {
  const files = point.requiredFiles.map((path) => ({
    path,
    exists: existsSync(resolve(root, path)),
  }));
  const controls = point.controlFiles.map((definition) =>
    evaluateControlFile(root, definition),
  );
  const commands = runCommands
    ? runValidationCommands(point.validationCommands, root)
    : point.validationCommands.map((command) => ({
        command,
        status: null,
        passed: false,
        skipped: true,
      }));

  const evidenceComplete = files.every((file) => file.exists);
  const controlsComplete = controls.every(
    (control) => control.exists && control.errors.length === 0,
  );
  const commandsComplete =
    point.validationCommands.length === 0 ||
    (runCommands &&
      commands.length === point.validationCommands.length &&
      commands.every((command) => command.passed));

  return {
    files,
    controls,
    commands,
    evidenceComplete,
    controlsComplete,
    commandsComplete,
    complete: evidenceComplete && controlsComplete && commandsComplete,
  };
}

function statusIcon(status) {
  switch (status) {
    case "verified":
      return "✅";
    case "active":
      return "🟠";
    default:
      return "⏸️";
  }
}

function buildReport(registry, validation, evaluation) {
  const verifiedCount = registry.points.filter(
    (point) => point.status === "verified",
  ).length;
  const lines = [
    "# Agent séquentiel iliprestō — 18 points",
    "",
    `- Progression officielle : **${verifiedCount}/18 points verified**`,
    `- Registre : \`quality/18-point-completion.json\``,
    `- Séquence valide : **${validation.errors.length === 0 ? "oui" : "non"}**`,
  ];

  if (validation.allVerified) {
    lines.push("- État : **programme terminé à 100 %**", "");
  } else if (validation.activePoint) {
    const point = validation.activePoint;
    lines.push(
      `- Point actif : **${point.id}. ${point.name}**`,
      `- Niveau initial audité : **${point.baselinePercent} %**`,
      `- Profil d’exécution : \`${point.environmentProfile}\``,
      `- Prêt à être promu : **${evaluation?.complete ? "oui" : "non"}**`,
      "",
      `## Point actif — ${point.id}. ${point.name}`,
      "",
      point.objective,
      "",
      "### Critères de fin",
      "",
      ...point.doneWhen.map((criterion) => `- [ ] ${criterion}`),
      "",
      "### Preuves obligatoires",
      "",
      "| Preuve | État |",
      "|---|---|",
      ...evaluation.files.map(
        (file) => `| \`${file.path}\` | ${file.exists ? "✅ présente" : "❌ absente"} |`,
      ),
      "",
      "### Registres de contrôle",
      "",
      "| Registre | Contrôles acceptés | État |",
      "|---|---:|---|",
      ...evaluation.controls.map(
        (control) =>
          `| \`${control.path}\` | ${control.controlsAccepted}/${control.controlsTotal} | ${
            control.errors.length === 0
              ? "✅ complet"
              : `❌ ${control.errors.join("; ")}`
          } |`,
      ),
      "",
      "### Commandes de validation",
      "",
      ...evaluation.commands.map((command) => {
        const state = command.skipped
          ? "⏳ à exécuter lors de la promotion"
          : command.passed
            ? "✅ réussite"
            : "❌ échec";
        return `- ${state} — \`${command.command}\``;
      }),
      "",
    );
  }

  if (validation.errors.length > 0) {
    lines.push(
      "## Erreurs de séquence",
      "",
      ...validation.errors.map((error) => `- ❌ ${error}`),
      "",
    );
  }

  lines.push(
    "## File séquentielle",
    "",
    "| Nº | Lot | Baseline | Statut |",
    "|---:|---|---:|---|",
    ...registry.points.map(
      (point) =>
        `| ${point.id} | ${point.name} | ${point.baselinePercent} % | ${statusIcon(point.status)} ${point.status} |`,
    ),
    "",
    "## Règle d’avancement",
    "",
    "Le point suivant n’est activé que par une promotion validée. La promotion exige toutes les preuves, tous les contrôles au statut accepté et la réussite de toutes les commandes du point actif. Une PR de promotion modifie alors uniquement le registre : le point courant passe à `verified` et le suivant à `active`.",
    "",
  );

  return `${lines.join("\n")}\n`;
}

function promoteRegistry(registry, activePoint) {
  const next = structuredClone(registry);
  const current = next.points.find((point) => point.id === activePoint.id);
  current.status = "verified";
  current.verifiedAt = new Date().toISOString();

  const nextPoint = next.points.find((point) => point.id === activePoint.id + 1);
  if (nextPoint) {
    nextPoint.status = "active";
    nextPoint.activatedAt = new Date().toISOString();
  }
  next.updatedAt = new Date().toISOString();
  return next;
}

export {
  buildReport,
  evaluatePoint,
  promoteRegistry,
  validateRegistry,
};

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const root = process.cwd();
  const registryPath = resolve(root, options.registry);
  const registry = readJson(registryPath);
  const validation = validateRegistry(registry);

  let evaluation = null;
  if (validation.activePoint && validation.errors.length === 0) {
    evaluation = evaluatePoint(validation.activePoint, root, {
      runCommands: options.runCommands,
    });
  }

  const state = {
    program: registry.program,
    validSequence: validation.errors.length === 0,
    sequenceErrors: validation.errors,
    allVerified: validation.allVerified,
    verifiedCount: registry.points.filter((point) => point.status === "verified")
      .length,
    activePoint: validation.activePoint
      ? {
          id: validation.activePoint.id,
          name: validation.activePoint.name,
          baselinePercent: validation.activePoint.baselinePercent,
          environmentProfile: validation.activePoint.environmentProfile,
        }
      : null,
    evaluation,
  };

  const report = buildReport(registry, validation, evaluation);
  if (options.reportPath) {
    const reportPath = resolve(root, options.reportPath);
    mkdirSync(dirname(reportPath), { recursive: true });
    writeFileSync(reportPath, report, "utf8");
  }

  if (options.promote) {
    if (validation.errors.length > 0) {
      throw new Error("Promotion impossible : séquence invalide.");
    }
    if (validation.allVerified) {
      throw new Error("Promotion impossible : les 18 points sont déjà verified.");
    }
    if (!evaluation?.complete) {
      throw new Error(
        `Promotion impossible : le point ${validation.activePoint.id} n’est pas complet.`,
      );
    }
    const promoted = promoteRegistry(registry, validation.activePoint);
    const outputPath = resolve(
      root,
      options.registryOutput ?? options.registry,
    );
    mkdirSync(dirname(outputPath), { recursive: true });
    writeFileSync(outputPath, `${JSON.stringify(promoted, null, 2)}\n`, "utf8");
    state.promotedPoint = validation.activePoint.id;
    state.nextActivePoint = promoted.points.find(
      (point) => point.status === "active",
    )?.id ?? null;
  }

  if (options.json) {
    process.stdout.write(`${JSON.stringify(state, null, 2)}\n`);
  } else {
    process.stdout.write(report);
  }

  if (validation.errors.length > 0) {
    process.exitCode = 2;
  } else if (options.requireComplete && !validation.allVerified && !evaluation?.complete) {
    process.exitCode = 3;
  }
}

const invokedPath = process.argv[1] ? pathToFileURL(resolve(process.argv[1])).href : null;
if (invokedPath === import.meta.url) {
  main().catch((error) => {
    console.error(`[18/18] ${error.stack ?? error.message}`);
    process.exitCode = 1;
  });
}
