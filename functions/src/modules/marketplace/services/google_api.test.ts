import assert from "node:assert/strict";
import test from "node:test";

import { assertAllowedGoogleApiUrl } from "./google_api";

test("accepte les hôtes Google réellement appelés", () => {
  assert.equal(
    assertAllowedGoogleApiUrl("https://vision.googleapis.com/v1/images:annotate").hostname,
    "vision.googleapis.com",
  );
  assert.equal(
    assertAllowedGoogleApiUrl(
      "https://recaptchaenterprise.googleapis.com/v1/projects/presto-app-74abe/assessments",
    ).hostname,
    "recaptchaenterprise.googleapis.com",
  );
});

test("refuse un hôte tiers", () => {
  assert.throws(
    () => assertAllowedGoogleApiUrl("https://attaquant.example.com/collect"),
    /Hôte Google API non autorisé : attaquant\.example\.com/,
  );
});

test("refuse un sous-domaine qui imite un hôte autorisé", () => {
  assert.throws(
    () => assertAllowedGoogleApiUrl("https://vision.googleapis.com.attaquant.example/v1"),
    /Hôte Google API non autorisé/,
  );
});

test("refuse un hôte Google non explicitement autorisé", () => {
  assert.throws(
    () => assertAllowedGoogleApiUrl("https://storage.googleapis.com/bucket/objet"),
    /Hôte Google API non autorisé : storage\.googleapis\.com/,
  );
});

test("refuse une URL non chiffrée", () => {
  assert.throws(
    () => assertAllowedGoogleApiUrl("http://vision.googleapis.com/v1/images:annotate"),
    /Google API URL non chiffrée/,
  );
});

test("refuse une URL illisible", () => {
  assert.throws(
    () => assertAllowedGoogleApiUrl("pas-une-url"),
    /Google API URL invalide/,
  );
});

test("refuse une tentative d échappement par identifiants d URL", () => {
  assert.throws(
    () =>
      assertAllowedGoogleApiUrl(
        "https://vision.googleapis.com@attaquant.example/v1/images:annotate",
      ),
    /Hôte Google API non autorisé : attaquant\.example/,
  );
});
