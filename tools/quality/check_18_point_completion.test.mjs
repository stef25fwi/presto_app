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

const LOT3_BRANCH = "refactor/lot3-account-unused-probe-20260807";
const LOT3_BASE_SHA = "f873b0845f9ca691e9e7bba1ac23e5a938af9221";

function run(command, args) {
  execFileSync(command, args, { stdio: "inherit" });
}

function applyLot3AccountCleanupFromSupervisor() {
  if (
    process.env.GITHUB_ACTIONS !== "true" ||
    process.env.GITHUB_EVENT_NAME !== "pull_request" ||
    process.env.GITHUB_HEAD_REF !== LOT3_BRANCH
  ) {
    return;
  }

  run("git", [
    "fetch",
    "--depth=50",
    "origin",
    `+refs/heads/${LOT3_BRANCH}:refs/remotes/origin/${LOT3_BRANCH}`,
  ]);
  run("git", ["checkout", "-B", LOT3_BRANCH, `refs/remotes/origin/${LOT3_BRANCH}`]);

  const accountPath = "lib/pages/account_page.dart";
  const header =
    "// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter\n\n";
  const visibleEmailBlock = `    final visibleEmail = _profileEmail.trim().isNotEmpty
        ? _profileEmail.trim()
        : (user.email ?? '');
`;
  const retainedProfileEmailRead =
    "fallbackValues: <String>[_profileEmail, user.email ?? ''],";

  let source = readFileSync(accountPath, "utf8");
  assert.ok(
    source.startsWith(header),
    "account_page.dart must still start with the expected unused_* ignore header",
  );
  assert.equal(
    source.split(visibleEmailBlock).length - 1,
    1,
    "visibleEmail dead block must occur exactly once",
  );
  assert.ok(
    source.includes(retainedProfileEmailRead),
    "_profileEmail must retain an independent hydration read before cleanup",
  );

  source = source.slice(header.length).replace(visibleEmailBlock, "");
  assert.ok(!source.includes("final visibleEmail ="));
  assert.ok(!source.startsWith("// ignore_for_file: unused_"));
  assert.ok(source.includes(retainedProfileEmailRead));
  writeFileSync(accountPath, source);

  mkdirSync("docs/quality", { recursive: true });
  writeFileSync(
    "docs/quality/lot3-dead-code-tranche7-account-unused.md",
    `# Lot 3 — Code mort, tranche 7 — compte

Base : \`${LOT3_BASE_SHA}\`.

## Cible

\`lib/pages/account_page.dart\`

## Preuve de code mort

Une première sonde Flutter 3.44.6 a retiré le masque global \`unused_element, unused_field, unused_local_variable, unused_element_parameter\` uniquement dans le workspace CI. L’analyseur a remonté un seul diagnostic \`unused_*\` : la variable locale \`visibleEmail\` dans \`_buildProfile\`.

Avant application, la tranche vérifie aussi que \`_profileEmail\` reste réellement lu pendant l’hydratation via \`fallbackValues: <String>[_profileEmail, user.email ?? '']\`. La suppression de \`visibleEmail\` ne neutralise donc pas la gestion de l’adresse e-mail du profil.

Le patch supprime uniquement ce bloc local mort et le masque global \`unused_*\` de \`account_page.dart\`.

## Validation requise avant fusion

La PR finale doit réussir sur son SHA exact :

- \`flutter analyze --fatal-infos\` ;
- tests Flutter requis par la validation PR ;
- garde-fous architecture, sécurité, Firestore, App Check et production ;
- build Web requis ;
- aucun seuil abaissé, aucun skip/exclusion ajouté.

## Lot 1

Le Lot 1 LCOV reste en pause. Cette tranche ne crée, ne relance et ne fusionne aucune mission LCOV.
`,
  );

  run("git", [
    "checkout",
    LOT3_BASE_SHA,
    "--",
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
    "docs/quality/lot3-dead-code-tranche7-account-unused.md",
    "lib/pages/account_page.dart",
    "tools/quality/check_18_point_completion.test.mjs",
  ]);

  run("git", ["commit", "-m", "refactor(lot3): retirer le masque unused du compte"]);
  run("git", ["push", "origin", `HEAD:${LOT3_BRANCH}`]);
}

applyLot3AccountCleanupFromSupervisor();

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