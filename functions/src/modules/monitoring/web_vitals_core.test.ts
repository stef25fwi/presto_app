import assert from "node:assert/strict";
import test from "node:test";

import {
  buildWebVitalsReport,
  classifyWebVital,
  normalizeWebVitalRoute,
  percentile,
  WebVitalSample,
} from "./web_vitals_core";

test("classifyWebVital applique les seuils Core Web Vitals", () => {
  assert.equal(classifyWebVital("LCP", 2500), "good");
  assert.equal(classifyWebVital("LCP", 2501), "needs-improvement");
  assert.equal(classifyWebVital("INP", 501), "poor");
  assert.equal(classifyWebVital("CLS", 0.1), "good");
});

test("percentile calcule le 75e centile sans interpolation", () => {
  assert.equal(percentile([1, 2, 3, 4], 0.75), 3);
  assert.equal(percentile([], 0.75), null);
});

test("normalizeWebVitalRoute retire les paramètres et anonymise les identifiants", () => {
  assert.equal(normalizeWebVitalRoute("/offres/123456?utm_source=test"), "/offres/:id");
  assert.equal(
    normalizeWebVitalRoute("/profil/550e8400-e29b-41d4-a716-446655440000"),
    "/profil/:id",
  );
  assert.equal(normalizeWebVitalRoute("guadeloupe/"), "/guadeloupe");
});

test("buildWebVitalsReport exige les trois métriques sur mobile et desktop", () => {
  const samples: WebVitalSample[] = [];
  for (const deviceCategory of ["mobile", "desktop"] as const) {
    for (let index = 0; index < 75; index += 1) {
      samples.push(
        { metric: "LCP", value: 2200, deviceCategory, route: "/" },
        { metric: "INP", value: 150, deviceCategory, route: "/" },
        { metric: "CLS", value: 0.05, deviceCategory, route: "/" },
      );
    }
  }

  const report = buildWebVitalsReport(samples);
  assert.equal(report.status, "pass");
  assert.equal(report.devices.mobile.metrics.LCP.p75, 2200);
  assert.equal(report.devices.desktop.metrics.INP.goodRate, 1);
});

test("buildWebVitalsReport reste insuffisant sans volume terrain", () => {
  const report = buildWebVitalsReport([
    { metric: "LCP", value: 2100, deviceCategory: "mobile", route: "/" },
  ]);
  assert.equal(report.status, "insufficient-data");
});

test("buildWebVitalsReport échoue si le p75 dépasse le seuil", () => {
  const samples: WebVitalSample[] = [];
  for (const deviceCategory of ["mobile", "desktop"] as const) {
    for (let index = 0; index < 75; index += 1) {
      samples.push(
        { metric: "LCP", value: deviceCategory === "mobile" ? 2800 : 2000, deviceCategory, route: "/" },
        { metric: "INP", value: 150, deviceCategory, route: "/" },
        { metric: "CLS", value: 0.05, deviceCategory, route: "/" },
      );
    }
  }
  const report = buildWebVitalsReport(samples);
  assert.equal(report.status, "fail");
  assert.equal(report.devices.mobile.metrics.LCP.status, "fail");
  assert.equal(report.devices.desktop.status, "pass");
});
