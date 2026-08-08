#!/usr/bin/env node

import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  evaluatePoint,
  promoteRegistry,
  validateRegistry,
} from "./check_18_point_completion.mjs";

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
