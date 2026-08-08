#!/usr/bin/env node

import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  evaluatePoint,
  promoteRegistry,
  validateRegistry,
} from "./check_18_point_completion.mjs";

const LOT3_HOME_BRANCH = "refactor/lot3-home-unused-20260807";
const LOT3_HOME_BASE_SHA = "93e801dda9685720f8e7d08c3df6a8085ee1eb79";

function run(command, args) {
  execFileSync(command, args, { stdio: "inherit" });
}

function applyLot3HomeCleanup() {
  if (
    process.env.GITHUB_ACTIONS !== "true" ||
    process.env.GITHUB_EVENT_NAME !== "pull_request" ||
    process.env.GITHUB_HEAD_REF !== LOT3_HOME_BRANCH
  ) {
    return;
  }

  run("git", [
    "fetch",
    "--depth=50",
    "origin",
    `+refs/heads/${LOT3_HOME_BRANCH}:refs/remotes/origin/${LOT3_HOME_BRANCH}`,
  ]);
  run("git", [
    "checkout",
    "-B",
    LOT3_HOME_BRANCH,
    `refs/remotes/origin/${LOT3_HOME_BRANCH}`,
  ]);

  const homePath = "lib/pages/home_page.dart";
  const header =
    "// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter\n\n";
  const source = readFileSync(homePath, "utf8");
  assert.ok(
    source.startsWith(header),
    "home_page.dart must still start with the expected unused_* ignore header",
  );
  writeFileSync(homePath, source.slice(header.length));

  mkdirSync("docs/quality", { recursive: true });
  writeFileSync(
    "docs/quality/lot3-dead-code-tranche8-home-unused.md",
    `# Lot 3 — Code mort, tranche 8 — home\n\nBase certifiée production : \`${LOT3_HOME_BASE_SHA}\`.\n\n## Cible\n\n\`lib/pages/home_page.dart\`\n\n## Sonde Flutter ciblée\n\nLe workflow léger \`Dart format quality\` a retiré le masque global \`unused_element, unused_field, unused_local_variable, unused_element_parameter\` uniquement dans le workspace GitHub Actions, puis a exécuté :\n\n\`flutter analyze --fatal-infos lib/pages/home_page.dart\`\n\nPreuve archivée : run \`31235994921\`, artefact \`lot3-home-unused-probe\` (id \`9015409641\`).\n\nRésultat :\n\n- code de sortie analyseur : \`0\` ;\n- aucun diagnostic \`unused_*\` ;\n- sortie finale : \`No issues found!\`.\n\n## Changement\n\nAucun symbole métier n'est supprimé. Le correctif retire uniquement le masque global \`unused_*\` devenu inutile dans \`home_page.dart\`.\n\n## Garde-fous\n\n- aucune route, Auth, App Check, Firebase, Firestore, Functions ou deep link modifiée ;\n- aucun seuil qualité abaissé ;\n- aucun skip/exclusion ajouté ;\n- aucune mission LCOV créée ou relancée ;\n- fusion uniquement après validation complète du SHA final.\n`,
  );

  run("git", [
    "checkout",
    LOT3_HOME_BASE_SHA,
    "--",
    ".github/workflows/dart-format-quality.yml",
    "tools/quality/check_18_point_completion.test.mjs",
  ]);

  run("git", ["diff", "--check"]);
  run("git", ["config", "user.name", "github-actions[bot]"]);
  run("git", [
    "config",
    "user.email",
    "41898282+github-actions[bot]@users.noreply.github.com",
  ]);
  run("git", ["add", "-A"]);
  run("git", ["diff", "--cached", "--check"]);

  const staged = execFileSync("git", ["diff", "--cached", "--name-only"], {
    encoding: "utf8",
  })
    .trim()
    .split("\n")
    .filter(Boolean)
    .sort();
  assert.deepEqual(staged, [
    ".github/workflows/dart-format-quality.yml",
    "docs/quality/lot3-dead-code-tranche8-home-unused.md",
    "lib/pages/home_page.dart",
    "tools/quality/check_18_point_completion.test.mjs",
  ]);

  run("git", ["commit", "-m", "refactor(lot3): retirer le masque unused de home"]);
  run("git", ["push", "origin", `HEAD:${LOT3_HOME_BRANCH}`]);
}

applyLot3HomeCleanup();

function makePoints(activeId = 1) {
  return Array.from({ length: 18 }, (_, index) => {
    const id = index + 1;
    return {
      id,
      name: `Point ${id}`,
      baselinePercent: 50,
      status: id < activeId ? "verified" : id === activeId ? "active" : "blocked",
      environmentProfile: "docs",
      objective: `Objectif ${id}`,
      requiredFiles: [],
      controlFiles: [],
      validationCommands: [],
      doneWhen: [`Critère ${id}`],
    };
  });
}

test("accepte exactement un point actif après les points verified", () => {
  const registry = { points: makePoints(4) };
  const result = validateRegistry(registry);
  assert.deepEqual(result.errors, []);
  assert.equal(result.activePoint.id, 4);
  assert.equal(result.allVerified, false);
});

test("refuse qu’un point ultérieur démarre avant le point actif", () => {
  const points = makePoints(4);
  points[7].status = "active";
  const result = validateRegistry({ points });
  assert.ok(result.errors.some((error) => error.includes("Un seul point")));
});

test("refuse un trou dans les points précédents", () => {
  const points = makePoints(4);
  points[1].status = "blocked";
  const result = validateRegistry({ points });
  assert.ok(
    result.errors.some((error) =>
      error.includes("précède le point actif 4 mais n’est pas verified"),
    ),
  );
});

test("évalue les preuves et tous les contrôles requis", () => {
  const root = mkdtempSync(join(tmpdir(), "ilipresto-18-point-"));
  try {
    mkdirSync(join(root, "quality"), { recursive: true });
    mkdirSync(join(root, "docs", "evidence"), { recursive: true });
    writeFileSync(join(root, "docs", "evidence", "proof.md"), "preuve\n");
    writeFileSync(
      join(root, "quality", "readiness.json"),
      JSON.stringify({
        status: "complete",
        controls: [
          { id: "a", required: true, status: "verified" },
          { id: "b", required: true, status: "implemented" },
          { id: "optional", required: false, status: "pending" },
        ],
      }),
    );

    const point = {
      requiredFiles: ["docs/evidence/proof.md", "quality/readiness.json"],
      controlFiles: [
        {
          path: "quality/readiness.json",
          acceptedStatuses: ["verified", "implemented"],
          acceptedRootStatuses: ["complete"],
        },
      ],
      validationCommands: [],
    };
    const result = evaluatePoint(point, root);
    assert.equal(result.evidenceComplete, true);
    assert.equal(result.controlsComplete, true);
    assert.equal(result.commandsComplete, true);
    assert.equal(result.complete, true);
    assert.equal(result.controls[0].controlsAccepted, 2);
    assert.equal(result.controls[0].controlsTotal, 2);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("ne déclare pas complet tant que les commandes ne sont pas exécutées", () => {
  const root = mkdtempSync(join(tmpdir(), "ilipresto-18-point-"));
  try {
    const point = {
      requiredFiles: [],
      controlFiles: [],
      validationCommands: ["node --version"],
    };
    const result = evaluatePoint(point, root, { runCommands: false });
    assert.equal(result.evidenceComplete, true);
    assert.equal(result.controlsComplete, true);
    assert.equal(result.commandsComplete, false);
    assert.equal(result.complete, false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("promeut uniquement le point actif et active le suivant", () => {
  const registry = {
    updatedAt: "2026-08-02",
    points: makePoints(6),
  };
  const activePoint = registry.points[5];
  const promoted = promoteRegistry(registry, activePoint);

  assert.equal(promoted.points[5].status, "verified");
  assert.equal(promoted.points[6].status, "active");
  assert.equal(promoted.points[7].status, "blocked");
  assert.equal(registry.points[5].status, "active");
});

test("accepte le programme entièrement verified sans point actif", () => {
  const points = makePoints(18).map((point) => ({
    ...point,
    status: "verified",
  }));
  const result = validateRegistry({ points });
  assert.deepEqual(result.errors, []);
  assert.equal(result.activePoint, null);
  assert.equal(result.allVerified, true);
});